import SwiftUI

struct LastWrapUpView: View {
    let lastFocusName: String
    let actions: [(category: String, anchor: String, completed: Bool)]
    let onContinue: () -> Void
    var dateString: String = ""
    var weatherCondition: String = ""
    var locationName: String = ""

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    private var fullInfoLine: String {
        ([dateString] + [weatherCondition, locationName].filter { !$0.isEmpty })
            .joined(separator: " · ")
    }

    private var completedCount: Int { actions.filter { $0.completed }.count }
    private var total: Int { actions.count }

    private var encouragementCopy: String {
        if total == 0 || completedCount == 0 {
            return String(localized: "wrapup.copy_none")
        } else if completedCount == total {
            return String(localized: "wrapup.copy_all")
        } else {
            return String(format: String(localized: "wrapup.copy_partial"), lastFocusName)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            // ── 左上角：日期（第一行）+ 天气 · 地点（第二行）──
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
                .padding(.leading, 32)
                .padding(.top, 60)
            }

            GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 0) {
                    // ── Card: title → focus name → count → checklist → encouragement ──
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
                            .padding(.bottom, 6)

                        // Completed count
                        if total > 0 {
                            Text(String(format: String(localized: "wrapup.completed"), completedCount, total))
                                .font(.custom("Merriweather-Regular", size: 14))
                                .foregroundColor(themeManager.descriptionText.opacity(0.7))
                                .padding(.bottom, 24)
                        }

                        // Action list — left-aligned icon + text
                        if !actions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(actions, id: \.category) { action in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: action.completed ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(
                                                action.completed
                                                ? Color(red: 0.94, green: 0.88, blue: 0.72)
                                                : themeManager.descriptionText.opacity(0.35)
                                            )
                                            .frame(width: 18, alignment: .leading)
                                        Text(action.anchor)
                                            .font(.custom("Merriweather-Regular", size: 14))
                                            .foregroundColor(
                                                action.completed
                                                ? themeManager.primaryText.opacity(0.75)
                                                : themeManager.descriptionText.opacity(0.5)
                                            )
                                            .strikethrough(action.completed, color: themeManager.descriptionText.opacity(0.4))
                                            .lineSpacing(4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 24)

                            // Divider
                            Rectangle()
                                .fill(themeManager.primaryText.opacity(0.10))
                                .frame(height: 1)
                                .padding(.bottom, 18)
                        }

                        // Encouragement copy
                        Text(encouragementCopy)
                            .font(.custom("Merriweather-Regular", size: 14))
                            .foregroundColor(themeManager.descriptionText.opacity(0.65))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            }
        }
    }
}
