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
        return "Version \(version)"
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

                        Text("about.title")
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

                    // Tagline
                    card {
                        Text("about.tagline")
                            .font(.custom("Merriweather-Italic", size: 18))
                            .foregroundColor(titleColor.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 4)
                    }

                    // What Alynna Is
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("about.align_inner_rhythm")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("about.align_description")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Today's Alignment (new)
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("✦")
                                    .font(.system(size: 20))
                                    .foregroundColor(titleColor)
                                Text("about.alignment_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                            }

                            // Example stars + keyword row, as a visual anchor.
                            // Mirrors exactly what users see on the mantra card.
                            HStack(spacing: 5) {
                                ForEach(0..<5, id: \.self) { i in
                                    FourPointStarShape()
                                        .fill(
                                            i < 4
                                                ? themeManager.accent.opacity(0.88)
                                                : themeManager.accent.opacity(0.22)
                                        )
                                        .frame(width: 11, height: 11)
                                }
                                Text(verbatim: "  柔软 · 起步 · 微光")
                                    .font(.custom("Merriweather-Regular", size: 11))
                                    .foregroundColor(bodyColor.opacity(0.58))
                                    .tracking(1.0)
                            }
                            .padding(.top, 2)

                            Text("about.alignment_body")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Three Companions Each Day: Mantra, Focus, Eight
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("about.daily_flow_title")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("about.daily_flow_intro")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)

                            // Mantra sub-section
                            VStack(alignment: .leading, spacing: 4) {
                                Text("about.daily_flow_mantra_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                                Text("about.daily_flow_mantra_desc")
                                    .font(AlynnaTypography.font(.subheadline))
                                    .foregroundColor(bodyColor)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)

                            // Focus sub-section
                            VStack(alignment: .leading, spacing: 4) {
                                Text("about.daily_flow_focus_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                                Text("about.daily_flow_focus_desc")
                                    .font(AlynnaTypography.font(.subheadline))
                                    .foregroundColor(bodyColor)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Eight anchors sub-section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("about.daily_flow_eight_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                                    .padding(.top, 2)

                                featureRow(
                                    emoji: "📍",
                                    title: String(localized: "about.place"),
                                    desc: String(localized: "about.place_desc")
                                )
                                featureRow(
                                    emoji: "🎨",
                                    title: String(localized: "about.color"),
                                    desc: String(localized: "about.color_desc")
                                )
                                featureRow(
                                    emoji: "🎵",
                                    title: String(localized: "about.sound"),
                                    desc: String(localized: "about.sound_desc")
                                )
                                featureRow(
                                    emoji: "🕯",
                                    title: String(localized: "about.scent"),
                                    desc: String(localized: "about.scent_desc")
                                )
                                featureRow(
                                    emoji: "🫖",
                                    title: String(localized: "about.activity"),
                                    desc: String(localized: "about.activity_desc")
                                )
                                featureRow(
                                    emoji: "🤝",
                                    title: String(localized: "about.relationship"),
                                    desc: String(localized: "about.relationship_desc")
                                )
                                featureRow(
                                    emoji: "💼",
                                    title: String(localized: "about.career"),
                                    desc: String(localized: "about.career_desc")
                                )
                                featureRow(
                                    emoji: "💎",
                                    title: String(localized: "about.gemstone"),
                                    desc: String(localized: "about.gemstone_desc")
                                )
                            }
                        }
                    }

                    // Moon Rituals (new)
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(titleColor.opacity(0.80))
                                Text("about.moon_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                            }

                            Text("about.moon_body")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // A Gentler Way
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("about.gentle_way")
                                .font(AlynnaTypography.font(.headline))
                                .foregroundColor(titleColor)

                            Text("about.gentle_description")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Privacy
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("🔒")
                                    .font(.system(size: 20))
                                Text("about.privacy_title")
                                    .font(AlynnaTypography.font(.headline))
                                    .foregroundColor(titleColor)
                            }

                            Text("about.privacy_description")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(bodyColor)
                                .lineSpacing(3)

                            VStack(alignment: .leading, spacing: 10) {
                                bullet(String(localized: "about.privacy_location"))
                                bullet(String(localized: "about.privacy_chart"))
                                bullet(String(localized: "about.privacy_transmission"))
                                bullet(String(localized: "about.privacy_control"))
                                bullet(String(localized: "about.privacy_moon"))
                            }
                            .padding(.top, 2)
                        }
                    }

                    VStack(spacing: 6) {
                        Text("about.copyright")
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
