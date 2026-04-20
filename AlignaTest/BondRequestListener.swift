import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - BondRequestListener
//
// Real-time listener on `bond_requests where to_uid == me and status == pending`.
// Fires the `onChange` callback whenever a new request arrives, is accepted,
// declined, expired, or cancelled — so the UI can re-pull the authoritative
// state from the backend via /bonds/my.
//
// This is our fallback for push notifications: instead of waking the device
// with an APNs banner, the user simply sees the updated state + badge as soon
// as they open the app (and in real time if they're already in it).
//
// Lifecycle: started on sign-in, stopped on sign-out. Managed by
// OnboardingViewModel.attachBondListener() / detachBondListener().

final class BondRequestListener {
    static let shared = BondRequestListener()

    private var registration: ListenerRegistration?
    private var currentUid: String?

    /// Invoked on the main thread every time the listener observes a change
    /// in the user's pending received bond requests.
    var onChange: (() -> Void)?

    private init() {}

    /// Start (or replace) the listener for the given uid. Safe to call
    /// repeatedly — no-op if already listening for this uid.
    func start(for uid: String) {
        if currentUid == uid, registration != nil { return }
        stop()
        currentUid = uid

        let query = Firestore.firestore()
            .collection("bond_requests")
            .whereField("to_uid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")

        registration = query.addSnapshotListener { [weak self] snap, err in
            if let err = err {
                print("⚠️ [BOND_LISTEN] snapshot error: \(err.localizedDescription)")
                return
            }
            let count = snap?.documents.count ?? 0
            print("🎧 [BOND_LISTEN] pending=\(count) for uid=\(uid.prefix(8))")
            // Fire on main thread; viewModel mutations happen on @MainActor.
            DispatchQueue.main.async {
                self?.onChange?()
            }
        }
    }

    /// Detach the listener. Called on sign-out or before switching uids.
    func stop() {
        registration?.remove()
        registration = nil
        currentUid = nil
    }
}
