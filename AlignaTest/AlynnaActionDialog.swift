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
                    .foregroundColor(iconForegroundColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(iconBackgroundColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(iconStrokeColor, lineWidth: 1)
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
                                        .fill(primaryButtonFill)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(primaryButtonStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if let secondaryButtonTitle {
                        Button {
                            let action = secondaryAction
                            onDismiss()
                            action?()
                        } label: {
                            Text(secondaryButtonTitle)
                                .font(.custom("Merriweather-Regular", size: 14))
                                .foregroundColor(themeManager.primaryText.opacity(0.95))
                                .frame(minWidth: 104)
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

    private var iconForegroundColor: Color {
        switch tone {
        case .success:
            return themeManager.isNight ? Color(hex: "#D8F3DF") : Color(hex: "#245C38")
        case .warning:
            return themeManager.isNight ? Color(hex: "#F8E2B8") : Color(hex: "#7A4A12")
        case .error:
            return themeManager.isNight ? Color(hex: "#FFD4D1") : Color(hex: "#8E2D2B")
        case .destructive:
            return themeManager.isNight ? Color(hex: "#FFD9D7") : Color(hex: "#A61D24")
        case .info:
            return themeManager.primaryText.opacity(0.92)
        }
    }

    private var iconBackgroundColor: Color {
        switch tone {
        case .success:
            return themeManager.isNight ? Color(hex: "#183326").opacity(0.98) : Color(hex: "#EFF8F1").opacity(0.98)
        case .warning:
            return themeManager.isNight ? Color(hex: "#352715").opacity(0.98) : Color(hex: "#FBF3E3").opacity(0.98)
        case .error:
            return themeManager.isNight ? Color(hex: "#341A1A").opacity(0.98) : Color(hex: "#FCEDEC").opacity(0.98)
        case .destructive:
            return themeManager.isNight ? Color(hex: "#3C1518").opacity(0.98) : Color(hex: "#FDE8E8").opacity(0.98)
        case .info:
            return themeManager.isNight ? Color(hex: "#182033").opacity(0.96) : Color.white.opacity(0.98)
        }
    }

    private var iconStrokeColor: Color {
        switch tone {
        case .success:
            return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.65 : 0.4)
        case .warning:
            return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.65 : 0.4)
        case .error:
            return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.65 : 0.4)
        case .destructive:
            return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.72 : 0.45)
        case .info:
            return themeManager.panelStrokeHi.opacity(0.8)
        }
    }

    private var primaryButtonFill: Color {
        switch tone {
        case .success:
            return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.28 : 0.18)
        case .warning:
            return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.3 : 0.2)
        case .error:
            return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.3 : 0.2)
        case .destructive:
            return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.34 : 0.22)
        case .info:
            return themeManager.accent.opacity(themeManager.isNight ? 0.28 : 0.18)
        }
    }

    private var primaryButtonStroke: Color {
        switch tone {
        case .success:
            return Color(hex: "#7DB58A").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .warning:
            return Color(hex: "#D4AE67").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .error:
            return Color(hex: "#D98E8A").opacity(themeManager.isNight ? 0.42 : 0.28)
        case .destructive:
            return Color(hex: "#D45C63").opacity(themeManager.isNight ? 0.5 : 0.34)
        case .info:
            return themeManager.panelStrokeHi.opacity(0.7)
        }
    }
}
