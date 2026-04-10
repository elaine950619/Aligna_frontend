import SwiftUI

struct AboutView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private var cardBG: Color { themeManager.onboardingPanelFill }
    private var border: Color { themeManager.onboardingPanelStroke }
    private var titleColor: Color { themeManager.onboardingPrimaryText }
    private var bodyColor: Color { themeManager.onboardingSecondaryText }
    private var accentFill: Color { themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.16 : 0.10) }
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? version
        if build == version {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    private var updatedText: String {
        guard
            let executableURL = Bundle.main.executableURL,
            let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
            let modifiedAt = attributes[.modificationDate] as? Date
        else {
            return "Updated date unavailable"
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: modifiedAt))"
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(accentFill)
                                .frame(width: 78, height: 78)
                                .overlay(
                                    Circle()
                                        .stroke(border, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(themeManager.isNight ? 0.18 : 0.10), radius: 18, x: 0, y: 10)

                            brandLogo(size: 38)
                        }
                        .padding(.top, 6)

                        Text("Alynna")
                            .font(AlynnaTypography.font(.title2))
                            .foregroundColor(titleColor)

                        VStack(spacing: 4) {
                            Text(versionText)
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor.opacity(0.88))

                            Text(updatedText)
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor.opacity(0.8))
                        }
                        .padding(.top, 2)

                        Rectangle()
                            .fill(titleColor.opacity(0.24))
                            .frame(width: 110, height: 1)
                            .padding(.top, 2)
                    }
                    .padding(.top, 10)

                    card {
                        Text("“Before you wake up, Alynna has already sensed the rhythm of your day.”")
                            .font(.custom("Merriweather-Italic", size: 18))
                            .foregroundColor(titleColor.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 4)
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Align Your Inner Rhythm")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("""
Alynna helps you align your inner rhythm with the world around you, guided by context, not just intuition.

A personalized rhythm card each day offers a short message with clear, actionable guidance to help you adjust your day.
""")
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(bodyColor)
                            .lineSpacing(3)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Eight Areas of Daily Support")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            featureRow(
                                emoji: "📍",
                                title: "Place",
                                desc: "Choose or adjust your environment to improve focus, rest, or recovery."
                            )

                            featureRow(
                                emoji: "🎨",
                                title: "Color",
                                desc: "Use specific colors to stabilize mood and support attention."
                            )

                            featureRow(
                                emoji: "🎧",
                                title: "Sound",
                                desc: "Reduce distractions and create a calmer mental space."
                            )

                            featureRow(
                                emoji: "🕯️",
                                title: "Scent",
                                desc: "Use scent to reset mood and support transitions, like work to rest."
                            )

                            featureRow(
                                emoji: "🚶",
                                title: "Activity",
                                desc: "Take actions that match your current energy level, such as focus, slow down, or reset."
                            )

                            featureRow(
                                emoji: "🤝",
                                title: "Relationship",
                                desc: "Adjust how you engage with others, such as connect, hold space, or set boundaries."
                            )

                            featureRow(
                                emoji: "💼",
                                title: "Career",
                                desc: "Align your work style with the day, such as deep work, planning, or lighter tasks."
                            )

                            featureRow(
                                emoji: "💎",
                                title: "Gemstone",
                                desc: "Use symbolic objects as simple anchors for focus and steadiness."
                            )
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A Gentle Way to Move Through the Day")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("""
Alynna is not about prediction or pressure.

It helps you make small, practical adjustments so you can move through the day with more clarity, balance, and ease.
""")
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(bodyColor)
                            .lineSpacing(3)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("🔒")
                                    .font(.system(size: 20))
                                Text("Data & Privacy")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                            }

                            Text("""
Your privacy is paramount. All sensor data is processed locally on your device. We do not collect, store, or share your personal information or location data.
""")
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(bodyColor)
                            .lineSpacing(3)

                            VStack(alignment: .leading, spacing: 10) {
                                bullet("Location data is used only for local weather and cosmic calculations")
                                bullet("Birth chart information remains private and secure")
                                bullet("No personal data is transmitted to external servers")
                                bullet("You have full control over your data and can delete it anytime")
                            }
                            .padding(.top, 2)
                        }
                    }

                    VStack(spacing: 6) {
                        Text("© 2026 Alynna. Made with cosmic intention")
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(bodyColor.opacity(0.75))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
//        .navigationTitle("About Alynna")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(themeManager.isNight ? 0.14 : 0.08), radius: 14, x: 0, y: 8)
    }

    private func featureRow(emoji: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 22, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AlynnaTypography.font(.headline))
                    .foregroundColor(titleColor)

                Text(desc)
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(bodyColor)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func brandLogo(size: CGFloat) -> some View {
        if UIImage(named: "alignaSymbol") != nil {
            Image("alignaSymbol")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(titleColor)
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(titleColor)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(bodyColor)
                .padding(.top, 1)

            Text(text)
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(bodyColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

#Preview("About Alynna") {
    NavigationStack {
        AboutView()
    }
    .environmentObject(ThemeManager())
}
