import Foundation
import CryptoKit

/// Source of truth for the user's favorite mantras. Mirrors the backend
/// `/users/me/favorites/mantras` collection, caches a local copy so the
/// list screen renders instantly on subsequent opens, and exposes
/// `isFavoritedToday(mantra:)` for the heart-button state.
@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var items: [FavoriteMantraItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastErrorMessage: String?

    /// Locally-persisted cache so first paint doesn't block on the network.
    private let cacheKey = "alynna_favorite_mantras_cache_v1"
    private let defaults = UserDefaults.standard

    private init() {
        loadFromCache()
    }

    // MARK: - Public surface

    /// Is today's version of `mantra` already saved by this user?
    /// Uses today's date in the *current* locale so the heart state matches
    /// the backend's doc-id synthesis (uid + YYYYMMDD(UTC) + sha1(mantra)).
    func isFavoritedToday(mantra: String) -> Bool {
        let trimmed = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let todayKey = Self.ymdUTC(Date())
        let digest = Self.mantraDigest(trimmed)
        return items.contains { item in
            // Doc id format: "{uid}_{YYYYMMDD}_{sha1[:10]}"
            item.id.hasSuffix("_\(todayKey)_\(digest)")
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await AlynnaAPI.shared.listFavoriteMantras()
            items = resp.items
            saveToCache()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    /// Optimistically toggle, rolling back on network failure. Returns the
    /// final state ("added" or "removed") once the server confirms.
    @discardableResult
    func toggle(snapshot: MantraSnapshot) async -> String? {
        let mantra = snapshot.mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mantra.isEmpty else { return nil }

        let wasOn = isFavoritedToday(mantra: mantra)
        let previousItems = items

        // Optimistic UI update
        if wasOn {
            let todayKey = Self.ymdUTC(Date())
            let digest = Self.mantraDigest(mantra)
            items.removeAll { $0.id.hasSuffix("_\(todayKey)_\(digest)") }
        }

        do {
            let resp = try await AlynnaAPI.shared.toggleFavoriteMantra(snapshot)
            if resp.toggled == "added", let item = resp.item {
                // Server confirms the add; prepend (newest first).
                items = [item] + items.filter { $0.id != item.id }
            } else if resp.toggled == "removed" {
                // Already removed optimistically; ensure consistent.
                let todayKey = Self.ymdUTC(Date())
                let digest = Self.mantraDigest(mantra)
                items.removeAll { $0.id.hasSuffix("_\(todayKey)_\(digest)") }
            }
            saveToCache()
            lastErrorMessage = nil
            return resp.toggled
        } catch {
            items = previousItems  // rollback
            saveToCache()
            lastErrorMessage = Self.describe(error)
            return nil
        }
    }

    /// Delete a favorite by id. Optimistic; rollback on failure.
    /// Returns the deleted item so the caller can offer an "undo" toast.
    @discardableResult
    func delete(id: String) async -> FavoriteMantraItem? {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = items.remove(at: idx)
        saveToCache()

        do {
            try await AlynnaAPI.shared.deleteFavoriteMantra(id: id)
            lastErrorMessage = nil
            return removed
        } catch {
            items.insert(removed, at: idx)
            saveToCache()
            lastErrorMessage = Self.describe(error)
            return nil
        }
    }

    /// Undo a prior delete by re-toggling the saved snapshot. Only useful
    /// if the undo happens on the same day as the original save.
    func undoDelete(snapshot: MantraSnapshot) async {
        _ = await toggle(snapshot: snapshot)
    }

    // MARK: - Cache

    private func loadFromCache() {
        guard let data = defaults.data(forKey: cacheKey) else { return }
        if let decoded = try? JSONDecoder().decode([FavoriteMantraItem].self, from: data) {
            items = decoded
        }
    }

    private func saveToCache() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Helpers

    private static func ymdUTC(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyyMMdd"
        return df.string(from: date)
    }

    private static func mantraDigest(_ mantra: String) -> String {
        let data = Data(mantra.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined().prefix(10).lowercased()
    }

    private static func describe(_ error: Error) -> String {
        if let apiErr = error as? AlynnaAPIError {
            return apiErr.errorDescription ?? String(describing: apiErr)
        }
        return error.localizedDescription
    }
}
