import Foundation
import FirebaseAuth

// MARK: - PushTokenRegistrar
//
// Thin coordination layer between Firebase Messaging and the Alynna backend.
// Responsibilities:
//   1. Receive FCM registration tokens (from AppDelegate / Messaging delegate)
//   2. Upload them to the backend via AlynnaAPI.registerFcmToken
//   3. Clear them on sign-out
//   4. Re-upload when the user's language preference changes
//
// This file is intentionally free of FirebaseMessaging imports so the
// project keeps compiling even before the Messaging dependency is added.
// The AppDelegate bridge (see PUSH_SETUP.md) is what actually feeds tokens
// into this registrar.

final class PushTokenRegistrar {
    static let shared = PushTokenRegistrar()

    private init() {}

    // MARK: - State
    //
    // We keep the last-registered (token, language) tuple so we only hit the
    // backend when something actually changes. Stored in UserDefaults so it
    // survives app relaunches and we avoid unnecessary network chatter.

    private let lastTokenKey = "alynna_push_last_registered_token"
    private let lastLanguageKey = "alynna_push_last_registered_language"

    private var lastRegisteredToken: String? {
        get { UserDefaults.standard.string(forKey: lastTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastTokenKey) }
    }

    private var lastRegisteredLanguage: String? {
        get { UserDefaults.standard.string(forKey: lastLanguageKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastLanguageKey) }
    }

    // MARK: - Public API

    /// Called by the Messaging delegate when an FCM token is issued or refreshed.
    /// Uploads to the backend — no-op if the user isn't signed in yet.
    func register(fcmToken: String, languageCode: String? = nil) {
        let trimmed = fcmToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let lang = languageCode ?? currentPreferredLanguage()

        // Skip redundant uploads.
        if trimmed == lastRegisteredToken && lang == lastRegisteredLanguage {
            return
        }

        // Must be signed in — if not, we'll retry on next auth state change.
        guard Auth.auth().currentUser != nil else {
            print("ℹ️ [PUSH] FCM token received but user not signed in; deferring")
            return
        }

        Task {
            do {
                try await AlynnaAPI.shared.registerFcmToken(trimmed, languageCode: lang)
                self.lastRegisteredToken = trimmed
                self.lastRegisteredLanguage = lang
                print("✓ [PUSH] FCM token registered (lang=\(lang ?? "?"))")
            } catch {
                print("⚠️ [PUSH] registerFcmToken failed: \(error.localizedDescription)")
                // Don't cache on failure — will retry on next token refresh.
            }
        }
    }

    /// Re-upload the cached token with a new language preference (e.g. the
    /// user toggled app language in Profile). No-op if we've never registered.
    func updateLanguage(_ newLanguage: String) {
        guard let token = lastRegisteredToken else { return }
        if newLanguage == lastRegisteredLanguage { return }
        register(fcmToken: token, languageCode: newLanguage)
    }

    /// Clear the backend-stored token and forget the local cache. Call on
    /// sign-out so a shared device doesn't deliver pushes meant for the
    /// previous account to the new one.
    func clearOnSignOut() {
        let hadToken = lastRegisteredToken != nil
        lastRegisteredToken = nil
        lastRegisteredLanguage = nil

        guard hadToken else { return }
        Task {
            do {
                try await AlynnaAPI.shared.unregisterFcmToken()
                print("✓ [PUSH] FCM token cleared on backend")
            } catch {
                // OK if it fails (e.g. user already signed out and token invalid).
                print("ℹ️ [PUSH] unregisterFcmToken: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func currentPreferredLanguage() -> String {
        // Prefer the user's explicit app-language setting if it exists;
        // fall back to system locale's language code.
        if let stored = UserDefaults.standard.string(forKey: "appLanguage"),
           !stored.isEmpty {
            return stored
        }
        let sys = Locale.current.identifier
        return sys.lowercased().hasPrefix("zh") ? "zh-Hans" : "en"
    }
}
