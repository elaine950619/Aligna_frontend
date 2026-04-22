import SwiftUI
import FirebaseAuth

/// A non-blocking reminder shown at the top of MainView when the signed-in
/// user used the email/password provider but hasn't confirmed their address
/// yet. Tapping "Resend" re-sends the verification email with a short cooldown
/// to prevent spam. The banner auto-disappears once the user's email is
/// verified (picked up on the next `user.reload()`).
struct EmailVerificationBanner: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnverifiedPasswordUser: Bool = false
    @State private var email: String = ""
    @State private var daysRemaining: Int = EmailVerificationGate.gracePeriodDays
    @State private var isLocked: Bool = false
    @State private var resendCooldownEndsAt: Date? = nil
    @State private var now: Date = Date()
    @State private var didDismissForSession: Bool = false
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cooldownSeconds: TimeInterval = 30

    var body: some View {
        Group {
            if isUnverifiedPasswordUser && !didDismissForSession {
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { refreshState() }
        .onReceive(tick) { t in now = t }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reloadAndRefresh()
            }
        }
    }

    private var bannerTitle: String {
        if isLocked { return String(localized: "verify.banner_title_locked") }
        return String(localized: "verify.banner_title")
    }

    private var bannerBody: String {
        if isLocked {
            return email.isEmpty
                ? String(localized: "verify.banner_body_locked_generic")
                : String(format: String(localized: "verify.banner_body_locked"), email)
        }
        // Urgent copy once we're within the last 2 days of grace.
        if daysRemaining <= 2 {
            return email.isEmpty
                ? String(format: String(localized: "verify.banner_body_urgent_generic"), daysRemaining)
                : String(format: String(localized: "verify.banner_body_urgent"), email, daysRemaining)
        }
        return email.isEmpty
            ? String(localized: "verify.banner_body_generic")
            : String(format: String(localized: "verify.banner_body"), email)
    }

    private var accent: Color {
        isLocked
            ? Color(red: 0.80, green: 0.30, blue: 0.28)
            : themeManager.accent
    }

    private var content: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isLocked ? "lock.fill" : "envelope.badge")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bannerTitle)
                        .font(.custom("Merriweather-Bold", size: 13))
                        .foregroundColor(themeManager.primaryText.opacity(0.92))
                    Text(bannerBody)
                        .font(.custom("Merriweather-Regular", size: 12))
                        .foregroundColor(themeManager.descriptionText.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button { didDismissForSession = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Button { resend() } label: {
                    Text(resendLabel)
                        .font(.custom("Merriweather-Regular", size: 12))
                        .foregroundColor(canResend ? themeManager.accent : themeManager.descriptionText.opacity(0.50))
                }
                .disabled(!canResend)
                .buttonStyle(.plain)
            }

            if showToast, let msg = toastMessage {
                Text(msg)
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(themeManager.descriptionText.opacity(0.80))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeManager.panelFill.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.30), lineWidth: 1)
                )
        )
    }

    // MARK: - State

    private var remainingSeconds: Int {
        guard let end = resendCooldownEndsAt else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded(.up)))
    }

    private var canResend: Bool { remainingSeconds == 0 }

    private var resendLabel: String {
        if canResend { return String(localized: "verify.banner_resend") }
        return String(format: String(localized: "verify.banner_resend_cooldown"), remainingSeconds)
    }

    private func refreshState() {
        isUnverifiedPasswordUser = EmailVerificationGate.isUnverifiedPasswordUser
        email = Auth.auth().currentUser?.email ?? ""
        daysRemaining = EmailVerificationGate.daysRemainingInGracePeriod ?? EmailVerificationGate.gracePeriodDays
        isLocked = EmailVerificationGate.isBondingRestricted
    }

    private func reloadAndRefresh() {
        guard let user = Auth.auth().currentUser else {
            isUnverifiedPasswordUser = false
            return
        }
        user.reload { _ in
            DispatchQueue.main.async { refreshState() }
        }
    }

    private func resend() {
        guard canResend, let user = Auth.auth().currentUser else { return }
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    toastMessage = error.localizedDescription
                } else {
                    toastMessage = String(localized: "verify.banner_resent_toast")
                }
                showToast = true
                resendCooldownEndsAt = Date().addingTimeInterval(cooldownSeconds)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showToast = false
                }
            }
        }
    }
}
