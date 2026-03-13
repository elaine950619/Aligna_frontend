import SwiftUI

struct AboutView: View {
    private var pageBG: Color { Color(.systemBackground) }
    private var cardBG: Color { Color(.secondarySystemBackground) }
    private var border: Color { Color.primary.opacity(0.10) }
    private var titleColor: Color { Color.primary }
    private var bodyColor: Color { Color.secondary }

    var body: some View {
        ZStack {
            pageBG.ignoresSafeArea()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(cardBG)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .stroke(border, lineWidth: 1)
                                )

                            Image(systemName: "leaf")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(titleColor)
                        }
                        .padding(.top, 6)

                        Text("About Alynna")
                            .font(AlignaTypography.font(.title2))
                            .foregroundColor(titleColor)

                        Rectangle()
                            .fill(titleColor.opacity(0.18))
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
                            Text("Your Energy Companion")
                                .font(AlignaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("""
Alynna is an energy companion app that blends astrology with spatial sensing to help you tune your daily flow. By combining your natal chart with your phone's sensors (location, weather, light, and magnetic field), Alynna creates a personalized energy phrase each morning and suggests colors, sounds, and rhythms to match.

With one gentle cue a day, Alynna helps you reconnect with your body, your space, and your inner balance, making life feel smoother, more attuned, and more aligned in the digital age.
""")
                            .font(AlignaTypography.font(.subheadline))
                            .foregroundColor(bodyColor)
                            .lineSpacing(3)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How Alynna Works")
                                .font(AlignaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            featureRow(
                                emoji: "🌟",
                                title: "Astrology Integration",
                                desc: "Your natal chart provides the cosmic foundation for personalized insights."
                            )

                            featureRow(
                                emoji: "📱",
                                title: "Spatial Sensing",
                                desc: "Phone sensors detect location, weather, light, and magnetic field data."
                            )

                            featureRow(
                                emoji: "🎨",
                                title: "Daily Recommendations",
                                desc: "Receive personalized suggestions for colors, sounds, and rhythms."
                            )

                            featureRow(
                                emoji: "⚖️",
                                title: "Inner Balance",
                                desc: "One gentle daily cue to help you stay aligned with your natural rhythm."
                            )
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("🔒")
                                    .font(.system(size: 20))
                                Text("Data & Privacy")
                                    .font(AlignaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                            }

                            Text("""
Your privacy is paramount. All sensor data is processed locally on your device. We do not collect, store, or share your personal information or location data.
""")
                            .font(AlignaTypography.font(.subheadline))
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
                        Text("Alynna Version 1.0")
                            .font(AlignaTypography.font(.subheadline))
                            .foregroundColor(bodyColor.opacity(0.85))

                        Text("© 2024 Alynna. Made with cosmic intention")
                            .font(AlignaTypography.font(.subheadline))
                            .foregroundColor(bodyColor.opacity(0.75))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationTitle("About Alynna")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func featureRow(emoji: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 22, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AlignaTypography.font(.headline))
                    .foregroundColor(titleColor)

                Text(desc)
                    .font(AlignaTypography.font(.subheadline))
                    .foregroundColor(bodyColor)
            }

            Spacer(minLength: 0)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(bodyColor)
                .padding(.top, 1)

            Text(text)
                .font(AlignaTypography.font(.subheadline))
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
}
