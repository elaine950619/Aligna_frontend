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

            // ── 左上角：日期 · 天气 · 地点（单行）──
            if !fullInfoLine.isEmpty {
                Text(fullInfoLine)
                    .font(.custom("Merriweather-Regular", size: 10))
                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                    .tracking(0.6)
                    .lineLimit(1)
                    .padding(.leading, 32)
                    .padding(.top, 60)
            }

            VStack(spacing: 0) {
                Spacer()

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

                    // Action list
                    if !actions.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(actions, id: \.category) { action in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: action.completed ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(
                                            action.completed
                                            ? Color(red: 0.94, green: 0.88, blue: 0.72)
                                            : themeManager.descriptionText.opacity(0.35)
                                        )
                                        .frame(width: 22)
                                    Text(action.anchor)
                                        .font(.custom("Merriweather-Regular", size: 14))
                                        .foregroundColor(
                                            action.completed
                                            ? themeManager.primaryText.opacity(0.75)
                                            : themeManager.descriptionText.opacity(0.5)
                                        )
                                        .strikethrough(action.completed, color: themeManager.descriptionText.opacity(0.4))
                                        .lineSpacing(4)
                                }
                            }
                        }
                        .padding(.bottom, 28)

                        // Divider
                        Rectangle()
                            .fill(themeManager.primaryText.opacity(0.08))
                            .frame(height: 1)
                            .padding(.bottom, 20)
                    }

                    // Encouragement copy
                    Text(encouragementCopy)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText.opacity(0.65))
                        .lineSpacing(5)
                        .padding(.bottom, 36)

                    // CTA button
                    Button {
                        onContinue()
                    } label: {
                        Text("wrapup.cta")
                            .font(.custom("Merriweather-Regular", size: 16))
                            .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.08))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.94, green: 0.88, blue: 0.72))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}
