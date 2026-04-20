import Foundation
import SwiftUI
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

// MARK: - Bonding-specific view model methods
//
// Kept in an extension (separate file) so that OnboardingViewModel itself
// remains a plain state container, and social-bonding concerns can be
// discovered / audited as a single module.
//
// All async methods are @MainActor because they mutate @Published state,
// which must happen on the main thread.

extension OnboardingViewModel {

    /// Load this user's Alynna number from the backend (idempotently allocating
    /// it if the server hasn't assigned one yet). No-op when:
    ///   - user is not signed in
    ///   - we already have the number cached in memory
    ///
    /// Safe to call repeatedly — e.g. from MainView.task on every foregrounding.
    @MainActor
    func ensureAlynnaNumberLoaded(force: Bool = false) async {
        guard Auth.auth().currentUser != nil else { return }
        if !force && !alynnaNumber.isEmpty { return }
        do {
            let resp = try await AlynnaAPI.shared.allocateNumber()
            if resp.alynna_number != alynnaNumber {
                alynnaNumber = resp.alynna_number
            }
            if !resp.already_allocated {
                // New allocation — useful signal for logging / analytics later.
                print("🔢 [ALYNNA] fresh allocation: \(resp.alynna_number.alynnaNumberDisplay)")
            }
        } catch {
            print("⚠️ [ALYNNA] allocateNumber failed: \(error.localizedDescription)")
            // Intentionally don't surface to user — this runs silently at launch.
            // If a UI needs the number and it's missing, it can re-trigger with force=true.
        }
    }

    /// Fetch this user's current bonds + pending requests and populate the
    /// four @Published fields. Call from bond-related UI's .task or pull-to-refresh.
    @MainActor
    func refreshBonds() async {
        guard Auth.auth().currentUser != nil else { return }
        do {
            let resp = try await AlynnaAPI.shared.myBonds()
            bonds = resp.bonds
            pendingReceivedRequests = resp.pending_received
            pendingSentRequests = resp.pending_sent
            bondingErrorMessage = nil
        } catch {
            print("⚠️ [ALYNNA] refreshBonds failed: \(error.localizedDescription)")
            bondingErrorMessage = error.localizedDescription
        }
    }

    /// Clear local bonding state. Call on sign-out so the next user doesn't
    /// see the previous user's bonds flashing on screen.
    @MainActor
    func clearBondingState() {
        alynnaNumber = ""
        bonds = []
        pendingReceivedRequests = []
        pendingSentRequests = []
        bondingErrorMessage = nil
        blockedNumbers = []
    }

    /// Fetch the current user's blocked numbers list directly from Firestore.
    /// This field is owned by the user, readable per security rules without
    /// a round-trip to the backend.
    @MainActor
    func loadBlockedNumbers() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()
            if let arr = snap.data()?["blocked_numbers"] as? [String] {
                blockedNumbers = arr
            } else {
                blockedNumbers = []
            }
        } catch {
            print("⚠️ [ALYNNA] loadBlockedNumbers failed: \(error.localizedDescription)")
        }
    }

    /// Block a number via the backend API and update local state.
    /// Accepts raw digits or formatted ("3847 2916").
    @MainActor
    func blockNumber(_ number: String) async throws {
        try await AlynnaAPI.shared.blockNumber(number)
        let digits = number.filter(\.isNumber)
        if !blockedNumbers.contains(digits) {
            blockedNumbers.append(digits)
        }
    }

    /// Unblock a previously-blocked number.
    @MainActor
    func unblockNumber(_ number: String) async throws {
        try await AlynnaAPI.shared.unblockNumber(number)
        let digits = number.filter(\.isNumber)
        blockedNumbers.removeAll { $0 == digits }
    }

    // MARK: - Real-time listener (fallback for push)

    /// Start the Firestore listener for incoming bond requests. Any change
    /// triggers a `refreshBonds()` + updates the app icon badge to reflect
    /// the current pending-received count. Safe to call repeatedly.
    @MainActor
    func attachBondListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        BondRequestListener.shared.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.refreshBonds()
                Self.updateAppIconBadge(count: self.pendingReceivedRequests.count)
            }
        }
        BondRequestListener.shared.start(for: uid)
    }

    /// Detach the listener and clear the badge. Call on sign-out.
    @MainActor
    func detachBondListener() {
        BondRequestListener.shared.stop()
        Self.updateAppIconBadge(count: 0)
    }

    /// Set the iOS app icon badge. Uses the new UserNotifications API on
    /// iOS 16+ and falls back to the deprecated UIApplication API otherwise.
    private static func updateAppIconBadge(count: Int) {
        let safe = max(0, count)
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(safe) { _ in }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = safe
            }
        }
    }
}
