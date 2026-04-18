import SwiftUI

struct LastWrapUpView: View {
    let lastFocusName: String
    let actions: [(category: String, anchor: String, completed: Bool)]
    let onContinue: () -> Void
    var dateString: String = ""
    var weatherCondition: String = ""
    var locationName: String = ""
    var onProfileTap: (() -> Void)? = nil

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    private var completedCount: Int { actions.filter { $0.completed }.count }
    private var total: Int { actions.count }

    private var wrapupEncouragement: String {
        if total == 0 || completedCount == 0 {
            return String(localized: "wrapup.progress_none")
        } else if completedCount == total {
            return String(format: String(localized: "wrapup.progress_all"), lastFocusName)
        } else {
            return String(format: String(localized: "wrapup.progress_partial"), lastFocusName)
        }
    }

    private func categorySymbol(for category: String) -> String {
        switch category {
        case "Activity":     return "figure.walk"
        case "Place":        return "location.fill"
        case "Sound":        return "waveform"
        case "Scent":        return "wind"
        case "Gemstone":     return "diamond.fill"
        case "Color":        return "paintpalette.fill"
        case "Career":       return "briefcase.fill"
        case "Relationship": return "heart.fill"
        default:             return "sparkle"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 0) {
                            // ── Card: title → focus name → checklist → progress ──
                            VStack(alignment: .leading, spacing: 0) {
                                // Title
                                Text("wrapup.title")
                                    .font(.custom("Merriweather-Regular", size: 13))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.5))
                                    .padding(.bottom, 10)

                                // Last session's focus name
                                Text(lastFocusName)
                                    .font(.custom("Merriweather-Bold", size: 28))
                                    .foregroundColor(themeManager.primaryText)
                                    .padding(.bottom, 20)

                                // Action list — card rows matching MainView style
                                if !actions.isEmpty {
                                    VStack(spacing: 6) {
                                        ForEach(actions, id: \.category) { action in
                                            let done = action.completed
                                            let iconSize: CGFloat = 30

                                            HStack(spacing: 10) {
                                                // Category circle + symbol
                                                ZStack {
                                                    Circle()
                                                        .fill(done
                                                            ? themeManager.primaryText.opacity(0.10)
                                                            : themeManager.primaryText.opacity(0.18))
                                                        .frame(width: iconSize, height: iconSize)
                                                    Image(systemName: categorySymbol(for: action.category))
                                                        .font(.system(size: iconSize * 0.52, weight: .medium))
                                                        .foregroundColor(done
                                                            ? themeManager.primaryText.opacity(0.28)
                                                            : themeManager.primaryText.opacity(0.80))
                                                }

                                                // Anchor text
                                                Text(action.anchor)
                                                    .font(.custom(done ? "Merriweather-Regular" : "Merriweather-Bold", size: 14))
                                                    .foregroundColor(done
                                                        ? themeManager.descriptionText.opacity(0.38)
                                                        : themeManager.primaryText.opacity(0.85))
                                                    .strikethrough(done, color: themeManager.descriptionText.opacity(0.30))
                                                    .lineLimit(2)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.horizontal, 13)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(themeManager.panelFill.opacity(done ? 0.10 : 0.24))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.white.opacity(done ? 0.05 : 0.09), lineWidth: 1)
                                            )
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 20)

                                    // Divider
                                    Rectangle()
                                        .fill(themeManager.primaryText.opacity(0.10))
                                        .frame(height: 1)
                                        .padding(.bottom, 18)
                                }

                                // Progress block: bar + count + encouragement
                                let isAllDone = completedCount > 0 && completedCount == total
                                let hasAny = completedCount > 0
                                let sandColor = Color(red: 0.94, green: 0.88, blue: 0.72)
                                let progress: CGFloat = total > 0 ? CGFloat(completedCount) / CGFloat(total) : 0

                                VStack(alignment: .leading, spacing: 10) {
                                    // Progress bar (only shown when there are actions)
                                    if total > 0 {
                                        GeometryReader { bar in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(themeManager.panelFill.opacity(0.30))
                                                    .frame(height: 3)
                                                if hasAny {
                                                    Capsule()
                                                        .fill(sandColor.opacity(isAllDone ? 0.90 : 0.70))
                                                        .frame(width: bar.size.width * progress, height: 3)
                                                }
                                            }
                                        }
                                        .frame(height: 3)

                                        // Count text
                                        Text(String(format: String(localized: "progress.completed_count"), completedCount, total))
                                            .font(.custom("Merriweather-Regular", size: 11))
                                            .foregroundColor(themeManager.descriptionText.opacity(0.55))
                                    }

                                    // Encouragement text
                                    Text(wrapupEncouragement)
                                        .font(.custom(isAllDone ? "Merriweather-Bold" : "Merriweather-Italic", size: 13))
                                        .foregroundColor(themeManager.primaryText.opacity(isAllDone ? 0.82 : 0.65))
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.panelFill.opacity(isAllDone ? 0.28 : 0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(sandColor.opacity(isAllDone ? 0.25 : 0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(themeManager.panelFill.opacity(0.38))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                            .padding(.bottom, 20)

                            // CTA button (outside the card)
                            Button {
                                onContinue()
                            } label: {
                                Text("wrapup.cta")
                                    .font(.custom("Merriweather-Regular", size: 16))
                                    .foregroundColor(Color(hex: "#5C3A1E").opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(red: 0.94, green: 0.88, blue: 0.72).opacity(themeManager.isNight ? 0.88 : 0.80))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 52)
                    }
                    .frame(minHeight: geo.size.height)
                }

                // ── 顶部浮层：日期 + 用户图标（在 ScrollView 上方，确保可点击）──
                HStack(alignment: .top) {
                    // 左上角：日期（第一行）+ 天气 · 地点（第二行）
                    if !dateString.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString)
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                .tracking(0.6)
                                .lineLimit(1)
                            let secondLine = ([weatherCondition, locationName].filter { !$0.isEmpty }).joined(separator: " · ")
                            if !secondLine.isEmpty {
                                Text(secondLine)
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                    .tracking(0.6)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    // 右上角：用户图标
                    if let onProfileTap {
                        Button(action: onProfileTap) {
                            Image("account")
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .foregroundColor(themeManager.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
                .allowsHitTesting(true)
            }
        }
    }
}
