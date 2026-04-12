import SwiftUI

struct AlynnaActionDialog: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let message: String
    let symbol: String
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let dismissButtonTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(themeManager.isNight ? 0.48 : 0.26)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(themeManager.primaryText.opacity(0.92))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(themeManager.isNight ? Color(hex: "#182033").opacity(0.96) : Color.white.opacity(0.98))
                    )
                    .overlay(
                        Circle()
                            .stroke(themeManager.panelStrokeHi.opacity(0.8), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Text(title)
                        .font(.custom("Merriweather-Bold", size: 18))
                        .foregroundColor(themeManager.primaryText.opacity(0.94))

                    Text(message)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    if let primaryButtonTitle {
                        Button {
                            let action = primaryAction
                            onDismiss()
                            action?()
                        } label: {
                            Text(primaryButtonTitle)
                                .font(.custom("Merriweather-Regular", size: 14))
                                .foregroundColor(themeManager.primaryText.opacity(0.95))
                                .frame(minWidth: 118)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(themeManager.accent.opacity(themeManager.isNight ? 0.28 : 0.18))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(themeManager.panelStrokeHi.opacity(0.7), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text(dismissButtonTitle)
                            .font(.custom("Merriweather-Regular", size: 14))
                            .foregroundColor(themeManager.primaryText.opacity(0.95))
                            .frame(minWidth: 92)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(themeManager.isNight ? Color(hex: "#202A40").opacity(0.98) : Color.white.opacity(0.98))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.panelStrokeHi.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 332)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(themeManager.isNight ? Color(hex: "#0F1726").opacity(0.98) : Color(hex: "#F5E6C8").opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(themeManager.isNight ? 0.35 : 0.16), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 28)
        }
    }
}
