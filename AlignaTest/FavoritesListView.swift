import SwiftUI

// MARK: - FavoriteMantraItem → MantraSnapshot bridge

extension FavoriteMantraItem {
    /// Reconstruct a MantraSnapshot so the saved moment can be re-rendered in
    /// ShareCardRenderView exactly as it looked when the user saved it.
    func toSnapshot() -> MantraSnapshot {
        MantraSnapshot(
            mantra: mantra,
            colorHex: color_hex ?? "#CBBBA0",
            score: score,
            keywords: keywords,
            focusId: focus_id,
            focusName: focus_name ?? "",
            locationName: location_name ?? "",
            weatherCondition: weather_condition ?? "",
            environmentSummary: environment_summary ?? "",
            sunSign: sun_sign ?? "",
            moonSign: moon_sign ?? "",
            risingSign: rising_sign ?? "",
            date: Self.parseISODate(saved_at),
            localeCode: locale ?? currentRecommendationLanguageCode()
        )
    }

    private static func parseISODate(_ iso: String) -> Date {
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso1.date(from: iso) { return d }
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let d = iso2.date(from: iso) { return d }
        return Date()
    }
}

// MARK: - FavoritesListView

struct FavoritesListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager
    @StateObject private var store = FavoritesStore.shared

    @State private var showUndoToast: Bool = false
    @State private var lastDeletedSnapshot: MantraSnapshot?
    @State private var undoTimer: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: 56)

                headerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                if store.items.isEmpty && !store.isLoading {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    list
                }
            }

            if showUndoToast {
                undoToast
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Custom back button overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "favorites.title"))
                .font(.custom("Merriweather-Bold", size: 22))
                .foregroundColor(themeManager.primaryText)
            Text(String(localized: "profile.favorites_subtitle"))
                .font(.custom("Merriweather-Light", size: 12))
                .foregroundColor(themeManager.descriptionText.opacity(0.70))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(store.items) { item in
                NavigationLink {
                    FavoriteDetailView(snapshot: item.toSnapshot(), itemId: item.id)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                } label: {
                    row(for: item)
                }
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        handleDelete(item: item)
                    } label: {
                        Label(String(localized: "favorites.delete"),
                              systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(for item: FavoriteMantraItem) -> some View {
        let isChinese = (item.locale ?? currentRecommendationLanguageCode()) == "zh-Hans"
        return VStack(alignment: .leading, spacing: 6) {
            Text(item.mantra)
                .font(isChinese
                      ? .custom("LXGWWenKaiTC-Regular", size: 15)
                      : .custom("Merriweather-Regular", size: 14))
                .foregroundColor(themeManager.primaryText.opacity(0.92))
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(formattedDate(item.saved_at, locale: item.locale))
                if let loc = item.location_name, !loc.isEmpty {
                    Text("·").foregroundColor(themeManager.descriptionText.opacity(0.30))
                    Text(loc).lineLimit(1)
                }
            }
            .font(.custom("Merriweather-Light", size: 10))
            .tracking(0.4)
            .foregroundColor(themeManager.descriptionText.opacity(0.55))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(themeManager.descriptionText.opacity(0.40))
            Text("favorites.empty_title")
                .font(.custom("Merriweather-Regular", size: 16))
                .foregroundColor(themeManager.primaryText.opacity(0.80))
            Text("favorites.empty_hint")
                .font(.custom("Merriweather-Light", size: 12))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Undo toast

    private var undoToast: some View {
        HStack(spacing: 14) {
            Text("favorites.deleted")
                .font(.custom("Merriweather-Regular", size: 13))
                .foregroundColor(Color(hex: "#F7F3EC").opacity(0.90))

            Button {
                undoDelete()
            } label: {
                Text("favorites.undo")
                    .font(.custom("Merriweather-Regular", size: 13))
                    .foregroundColor(Color(hex: "#F7F3EC"))
                    .underline()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.75))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func handleDelete(item: FavoriteMantraItem) {
        let snapshot = item.toSnapshot()
        Task { @MainActor in
            let removed = await store.delete(id: item.id)
            if removed != nil {
                lastDeletedSnapshot = snapshot
                withAnimation(.easeInOut(duration: 0.25)) { showUndoToast = true }
                undoTimer?.cancel()
                undoTimer = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) { showUndoToast = false }
                    lastDeletedSnapshot = nil
                }
            }
        }
    }

    private func undoDelete() {
        guard let snapshot = lastDeletedSnapshot else { return }
        undoTimer?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { showUndoToast = false }
        Task { @MainActor in
            await store.undoDelete(snapshot: snapshot)
            lastDeletedSnapshot = nil
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ iso: String, locale: String?) -> String {
        let parsed = FavoriteMantraItem.__parseForDisplay(iso)
        let df = DateFormatter()
        df.locale = Locale(identifier: locale ?? currentRecommendationLanguageCode())
        df.setLocalizedDateFormatFromTemplate("yMMMd")
        return df.string(from: parsed)
    }
}

fileprivate extension FavoriteMantraItem {
    static func __parseForDisplay(_ iso: String) -> Date {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: iso) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: iso) { return d }
        return Date()
    }
}

