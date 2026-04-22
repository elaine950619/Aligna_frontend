import Foundation
import FirebaseAuth

/// Centralised policy for "how unverified emails gate access to sensitive
/// features". The current policy:
///
///   - Apple / Google signed-in users are considered verified by their
///     provider and never hit a gate.
///   - Password signed-in users get a 7-day grace window from account
///     creation. During grace, only a non-blocking banner nags them.
///   - After the grace window, bonding features (sending / accepting
///     bond requests) are locked on the client until they verify.
///
/// Enforcement is client-side only in v1 — intentionally. Backend
/// enforcement can be added later by wrapping bond endpoints with a
/// `require_verified_email` dependency.
enum EmailVerificationGate {
    static let gracePeriodDays: Int = 7

    private static var currentUser: User? { Auth.auth().currentUser }

    /// True when the signed-in user authenticated with email+password
    /// and hasn't completed the verification link yet.
    static var isUnverifiedPasswordUser: Bool {
        guard let user = currentUser else { return false }
        let usesPassword = user.providerData.contains { $0.providerID == "password" }
        return usesPassword && !user.isEmailVerified
    }

    /// Whole days elapsed since the Firebase account was created.
    /// Nil when there's no signed-in user or no creation timestamp.
    static var daysSinceAccountCreation: Int? {
        guard let creation = currentUser?.metadata.creationDate else { return nil }
        let elapsed = Date().timeIntervalSince(creation)
        return max(0, Int(floor(elapsed / 86_400)))
    }

    /// Days until the grace period ends, clamped at 0. Nil if the user
    /// isn't an unverified password user at all.
    static var daysRemainingInGracePeriod: Int? {
        guard isUnverifiedPasswordUser, let days = daysSinceAccountCreation else { return nil }
        return max(0, gracePeriodDays - days)
    }

    /// Still inside the 7-day nag window (banner only, no feature lock).
    static var isInGracePeriod: Bool {
        guard isUnverifiedPasswordUser, let days = daysSinceAccountCreation else { return false }
        return days < gracePeriodDays
    }

    /// Bonding features should be blocked with a "verify email first" modal.
    static var isBondingRestricted: Bool {
        guard isUnverifiedPasswordUser, let days = daysSinceAccountCreation else { return false }
        return days >= gracePeriodDays
    }

    /// Force a token refresh + profile reload so `isEmailVerified` reflects
    /// whatever the user might have done on another device / in a browser.
    static func refreshVerificationStatus() async {
        guard let user = currentUser else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            user.reload { _ in cont.resume() }
        }
    }

    /// Send a new verification email from whatever surface is prompting the
    /// user to verify (banner, bond lock dialog, etc.).
    static func resendVerificationEmail(_ completion: ((Error?) -> Void)? = nil) {
        guard let user = currentUser else {
            completion?(NSError(domain: "EmailVerificationGate", code: -1))
            return
        }
        user.sendEmailVerification(completion: completion)
    }
}
