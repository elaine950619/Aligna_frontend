import SwiftUI
import FirebaseAuth

/// A small, non-blocking notice shown at the top of OnboardingStep0 right
/// after email signup. Tells the user:
///   1. A verification link was sent (and to which address)
///   2. They have a 7-day grace window
///   3. Bonding features will be locked if they don't verify in time
///
/// Intentionally not dismissable — the user only sees Step0 once, so there's
/// no recurring-nag concern, and the message needs to stick long enough to
/// register. The ongoing reminder lives on MainView (EmailVerificationBanner).
struct VerifyEmailNoticeBar: View {
    @EnvironmentObject var themeManager: ThemeManager

    private var email: String {
        Auth.auth().currentUser?.email ?? ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(email.isEmpty
                     ? String(localized: "verify.onboarding_notice_title_generic")
                     : String(format: String(localized: "verify.onboarding_notice_title"), email))
                    .font(.custom("Merriweather-Bold", size: 13))
                    .foregroundColor(themeManager.primaryText.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: String(localized: "verify.onboarding_notice_body"), EmailVerificationGate.gracePeriodDays))
                    .font(.custom("Merriweather-Regular", size: 12))
                    .foregroundColor(themeManager.descriptionText.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeManager.panelFill.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(themeManager.accent.opacity(0.30), lineWidth: 1)
                )
        )
    }
}
