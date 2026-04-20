import SwiftUI

enum AlynnaDialogTone {
    case info
    case success
    case warning
    case error
    case destructive
}

struct AlynnaActionDialog: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let message: String
    let symbol: String
    let tone: AlynnaDialogTone
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    let dismissButtonTitle: String
    let onDismiss: () -> Void

    init(
        title: String,
        message: String,
        symbol: String,
        tone: AlynnaDialogTone = .info,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        dismissButtonTitle: String,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tone = tone
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
        self.dismissButtonTitle = dismissButtonTitle
        self.onDismiss = onDismiss
    }

    // Three buttons → vertical stack; one or two → horizontal row.
    private var useVerticalLayout: Bool {
        primaryButtonTitle != nil && secondaryButtonTitle != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(themeManager.isNight ? 0.48 : 0.26)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                // Icon
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconForegroundColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(iconBackgroundColor))
                    .overlay(Circle().stroke(iconStrokeColor, lineWidth: 1))

                // Title + message
                VStack(spacing: 10) {
                    Text(title)
                        .font(.custom("Merriweather-Bold", size: 18))
                        .foregroundColor(themeManager.primaryText.opacity(0.94))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 4)

                // Buttons — layout adapts to count
                if useVerticalLayout {
                    verticalButtons
                } else {
                    horizontalButtons
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 332)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(themeManager.isNight ? 0.35 : 0.16), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Button layouts

    /// 3-button vertical stack: primary (strongest) → secondary (same tone, lighter) → dismiss (ghost, separated)
    @ViewBuilder
    private var verticalButtons: some View {
        VStack(spacing: 0) {
            // Primary action
            if let title = primaryButtonTitle {
                actionButton(
                    label: title,
                    fill: primaryButtonFill,
                    stroke: primaryButtonStroke,
                    isBold: true
                ) {
                    let action = primaryAction
                    onDismiss()
                    action?()
                }
            }

            // Gap + thin separator + gap between the two destructive/primary actions
            Spacer().frame(height: 8)
            Rectangle()
                .fill(themeManager.panelStrokeHi.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 8)
            Spacer().frame(height: 8)

            // Secondary action — same tone fill but lower opacity
            if let title = secondaryButtonTitle {
                actionButton(
                    label: title,
                    fill: secondaryButtonFill,
                    stroke: secondaryButtonStroke,
                    isBold: false
                ) {
                    let action = secondaryAction
                    onDismiss()
                    action?()
                }
            }

            // Visual gap before dismiss — signals "safe zone below"
            Spacer().frame(height: 16)

            // Dismiss — ghost style (no fill, only border) to signal safety
            Button { onDismiss() } label: {
                Text(dismissButtonTitle)
                    .font(.custom("Merriweather-Regular", size: 14))
                    .foregroundColor(themeManager.descriptionText.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(themeManager.panelStrokeHi.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// 1- or 2-button horizontal row (classic layout for simple confirm/cancel).
    @ViewBuilder
    private var horizontalButtons: some View {
        HStack(spacing: 10) {
            if let title = primaryButtonTitle {
                Button {
                    let action = primaryAction
                    onDismiss()
                    action?()
                } label: {
                    Text(title)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.primaryText.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(primaryButtonFill))
                        .overlay(Capsule().stroke(primaryButtonStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button { onDismiss() } label: {
                Text(dismissButtonTitle)
                    .font(.custom("Merriweather-Regular", size: 14))
                    .foregroundColor(themeManager.primaryText.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(themeManager.isNight ? Color(hex: "#192840").opacity(0.98) : Color.white.opacity(0.98))
                    )
                    .overlay(
                        Capsule()
                            .stroke(themeManager.panelStrokeHi.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // Reusable full-width button for the vertical layout
    private func actionButton(
        label: String,
        fill: Color,
        stroke: Color,
        isBold: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(isBold ? "Merriweather-Bold" : "Merriweather-Regular", size: 14))
                .foregroundColor(themeManager.primaryText.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colour helpers

    private var cardFill: Color {
        if themeManager.isRain     { return Color(hex: "#131F2E").opacity(0.98) }
        if themeManager.isVitality { return Color(hex: "#EDF7EC").opacity(0.98) }
        if themeManager.isLove     { return Color(hex: "#FDE8F0").opacity(0.98) }
        if themeManager.isNight    { return Color(hex: "#0F1726").opacity(0.98) }
        return Color(hex: "#F5E6C8").opacity(0.98)
    }

    private var iconForegroundColor: Color {
        switch tone {
        case .success:     return themeManager.isNight ? Color(hex: "#D8F3DF") : Color(hex: "#245C38")
        case .warning:     return themeManager.isNight ? Color(hex: "#F8E2B8") : Color(hex: "#7A4A12")
        case .error:       return themeManager.isNight ? Color(hex: "#FFD4D1") : Color(hex: "#8E2D2B")
        case .destructive: return themeManager.isNight ? Color(hex: "#FFD9D7") : Color(hex: "#A61D24")
        case .info:        return themeManager.primaryText.opacity(0.92)
        }
    }

    private var iconBackgroundColor: Color {
        switch tone {
        case .success:     return themeManager.isNight ? Color(hex: "#183326").opacity(0.98) : Color(hex: "#EFF8F1").opacity(0.98)
        case .warning:     return themeManager.isNight ? Color(hex: "#352715").opacity(0.98) : Color(hex: "#FBF3E3").opacity(0.98)
        case .error:       return themeManager.isNight ? Color(hex: "#341A1A").opacity(0.98) : Color(hex: "#FCEDEC").opacity(0.98)
        case .destructive: return themeManager.isNight ? Color(hex: "#3C1518").opacity(0.98) : Color(hex: "#FDE8E8").opacity(0.98)
        case .info:        return themeManager.isNight ? Color(hex: "#182033").opacity(0.96) : Color.white.opacity(0.98)
        }
    }

    private var iconStrokeColor: Color {
        switch tone {
        case .success:     return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.65 : 0.40)
        case .warning:     return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.65 : 0.40)
        case .error:       return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.65 : 0.40)
        case .destructive: return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.72 : 0.45)
        case .info:        return themeManager.panelStrokeHi.opacity(0.8)
        }
    }

    private var primaryButtonFill: Color {
        switch tone {
        case .success:     return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.28 : 0.18)
        case .warning:     return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.30 : 0.20)
        case .error:       return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.30 : 0.20)
        case .destructive: return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.34 : 0.22)
        case .info:        return themeManager.accent.opacity(themeManager.isNight ? 0.28 : 0.18)
        }
    }

    private var primaryButtonStroke: Color {
        switch tone {
        case .success:     return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .warning:     return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .error:       return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .destructive: return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.50 : 0.34)
        case .info:        return themeManager.panelStrokeHi.opacity(0.7)
        }
    }

    // Secondary: same hue as primary at roughly half opacity — visually subordinate but tonally related
    private var secondaryButtonFill: Color {
        switch tone {
        case .success:     return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.16 : 0.10)
        case .warning:     return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.18 : 0.12)
        case .error:       return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.18 : 0.12)
        case .destructive: return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.20 : 0.12)
        case .info:        return themeManager.accent.opacity(themeManager.isNight ? 0.16 : 0.10)
        }
    }

    private var secondaryButtonStroke: Color {
        switch tone {
        case .success:     return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.28 : 0.18)
        case .warning:     return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.28 : 0.18)
        case .error:       return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.28 : 0.18)
        case .destructive: return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.32 : 0.20)
        case .info:        return themeManager.panelStrokeHi.opacity(0.5)
        }
    }
}
