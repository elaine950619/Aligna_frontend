import Foundation
import SwiftUI
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
}
