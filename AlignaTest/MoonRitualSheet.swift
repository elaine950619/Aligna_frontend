import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - MoonRitualBanner

/// Compact horizontal banner shown in the collapsed mantra card.
/// Taps open MoonRitualSheet.
struct MoonRitualBanner: View {
    let phase: MoonPhase
    let isCompleted: Bool
    let onTap: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    /// Phase-specific ritual accent (independent of theme).
    private var phaseAccent: Color {
        switch phase {
        case .new:  return Color(hex: "#7A9CC8")   // moonlit blue
        case .full: return Color(hex: "#C8943A")   // warm gold
        default:    return Color(hex: "#7A9CC8")
        }
    }

    // Crescent + stars for new moon (visible at any size);
    // full moon disc for full moon.
    private var symbol: String {
        switch phase {
        case .new:  return "moon.stars.fill"
        case .full: return "moonphase.full.moon"
        default:    return "moon.stars.fill"
        }
    }

    private var titleKey: String {
        switch phase {
        case .new:  return "moon.new_title"
        case .full: return "moon.full_title"
        default:    return "moon.new_title"
        }
    }

    private var subtitleKey: String {
        switch phase {
        case .new:  return "moon.new_subtitle"
        case .full: return "moon.full_subtitle"
        default:    return "moon.new_subtitle"
        }
    }

    /// True when the active theme uses a dark background.
    private var isDarkTheme: Bool {
        themeManager.isNight || themeManager.isRain
    }

    /// Primary label color: accent on dark themes (high contrast), theme primary text on light themes.
    private var labelColor: Color {
        isDarkTheme ? phaseAccent : themeManager.primaryText
    }

    /// Secondary/subtitle color.
    private var subtitleColor: Color {
        isDarkTheme
            ? Color.white.opacity(isCompleted ? 0.28 : 0.50)
            : themeManager.descriptionText.opacity(isCompleted ? 0.45 : 0.75)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                MoonSymbolView(phase: phase, size: 22, accent: phaseAccent,
                               opacity: isCompleted ? 0.45 : 0.90)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: String.LocalizationValue(titleKey)))
                        .font(.custom("Merriweather-Bold", size: 12))
                        .foregroundColor(labelColor.opacity(isCompleted ? 0.45 : 0.85))
                        .tracking(0.4)

                    Text(String(localized: String.LocalizationValue(subtitleKey)))
                        .font(.custom("Merriweather-Regular", size: 10))
                        .foregroundColor(subtitleColor)
                        .tracking(0.2)
                        .lineLimit(1)
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(phaseAccent.opacity(0.50))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(isDarkTheme
                            ? Color.white.opacity(0.35)
                            : themeManager.descriptionText.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeManager.panelFill.opacity(isCompleted ? 0.65 : 0.85))
                    // Subtle phase-tint overlay on top of panel background
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(phaseAccent.opacity(isDarkTheme ? 0.08 : 0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(phaseAccent.opacity(isCompleted ? 0.10 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MoonRitualSheet

struct MoonRitualSheet: View {
    let phase: MoonPhase
    let isCompleted: Bool
    let onComplete: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // Three intention / release lines
    @State private var lines: [String] = ["", "", ""]
    @State private var isSaving = false
    @State private var isLoadingExisting = false
    @FocusState private var focusedIndex: Int?

    // MARK: Phase identity (independent of theme)

    /// Ritual accent color — moonlit blue (new) or warm gold (full).
    private var phaseAccent: Color {
        switch phase {
        case .new:  return Color(hex: "#7A9CC8")
        case .full: return Color(hex: "#C8943A")
        default:    return Color(hex: "#7A9CC8")
        }
    }

    private var symbol: String {
        switch phase {
        case .new:  return "moon.stars.fill"
        case .full: return "moonphase.full.moon"
        default:    return "moon.stars.fill"
        }
    }

    private var titleKey: String {
        switch phase {
        case .new:  return "moon.new_title"
        case .full: return "moon.full_title"
        default:    return "moon.new_title"
        }
    }

    private var promptKey: String {
        switch phase {
        case .new:  return "moon.new_prompt"
        case .full: return "moon.full_prompt"
        default:    return "moon.new_prompt"
        }
    }

    private var placeholderKeys: [String] {
        switch phase {
        case .new:  return ["moon.new_ph1", "moon.new_ph2", "moon.new_ph3"]
        case .full: return ["moon.full_ph1", "moon.full_ph2", "moon.full_ph3"]
        default:    return ["moon.new_ph1", "moon.new_ph2", "moon.new_ph3"]
        }
    }

    // MARK: Theme-derived colors

    /// Dark-background themes (Night, Rain) keep a deep atmospheric bg;
    /// light themes (Day, Vitality, Love) use a soft themed background.
    private var isDarkTheme: Bool {
        themeManager.isNight || themeManager.isRain
    }

    /// Sheet background color.
    private var sheetBg: Color {
        if themeManager.isNight {
            return Color(hex: "#0D0D1A")       // deep indigo-black
        } else if themeManager.isRain {
            return Color(hex: "#17222B")       // muted slate
        } else if themeManager.isVitality {
            return Color(hex: "#EFF4ED")       // soft sage white
        } else if themeManager.isLove {
            return Color(hex: "#F5EEF0")       // dusty rose blush
        } else {
            return Color(hex: "#F4ECE1")       // warm muted ivory
        }
    }

    /// Heading text color.
    private var headingColor: Color {
        isDarkTheme ? Color.white.opacity(0.88) : themeManager.primaryText
    }

    /// Body/prompt text color.
    private var bodyColor: Color {
        isDarkTheme ? Color.white.opacity(0.50) : themeManager.descriptionText
    }

    /// Text field input text.
    private var inputTextColor: Color {
        isDarkTheme ? Color.white.opacity(0.85) : themeManager.primaryText
    }

    /// Placeholder text color.
    private var placeholderColor: Color {
        isDarkTheme ? Color.white.opacity(0.22) : themeManager.descriptionText.opacity(0.35)
    }

    /// Input row background.
    private var rowFill: Color {
        isDarkTheme ? Color.white.opacity(0.05) : themeManager.panelFill.opacity(0.80)
    }

    /// Input row border (unfocused).
    private var rowBorderIdle: Color {
        isDarkTheme ? Color.white.opacity(0.10) : themeManager.panelStrokeHi.opacity(0.60)
    }

    /// Save button label color: on dark themes use the deep bg (legible on accent); on light use white.
    private var saveButtonLabel: Color {
        isDarkTheme ? sheetBg : Color.white
    }

    private var canSave: Bool {
        lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    var body: some View {
        ZStack {
            sheetBg.ignoresSafeArea()

            // Soft phase-colored glow behind the moon icon
            Circle()
                .fill(phaseAccent.opacity(isDarkTheme ? 0.07 : 0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(y: -120)

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    MoonSymbolView(phase: phase, size: 48, accent: phaseAccent,
                                   opacity: 0.88)
                        .padding(.top, 36)

                    Text(String(localized: String.LocalizationValue(titleKey)))
                        .font(.custom("Merriweather-Bold", size: 22))
                        .foregroundColor(headingColor)

                    Text(String(localized: String.LocalizationValue(promptKey)))
                        .font(.custom("Merriweather-Regular", size: 13))
                        .foregroundColor(bodyColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 36)
                }
                .padding(.bottom, 32)

                // Three input lines
                VStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { idx in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.custom("Merriweather-Regular", size: 13))
                                .foregroundColor(phaseAccent.opacity(0.55))
                                .frame(width: 16)

                            ZStack(alignment: .leading) {
                                if lines[idx].isEmpty {
                                    Text(String(localized: String.LocalizationValue(placeholderKeys[idx])))
                                        .font(.custom("Merriweather-Regular", size: 14))
                                        .foregroundColor(placeholderColor)
                                }
                                TextField("", text: $lines[idx])
                                    .font(.custom("Merriweather-Regular", size: 14))
                                    .foregroundColor(inputTextColor)
                                    .focused($focusedIndex, equals: idx)
                                    .submitLabel(idx < 2 ? .next : .done)
                                    .onSubmit {
                                        if idx < 2 { focusedIndex = idx + 1 }
                                        else { focusedIndex = nil }
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(rowFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    focusedIndex == idx
                                        ? phaseAccent.opacity(0.50)
                                        : rowBorderIdle,
                                    lineWidth: 1
                                )
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 32)

                // Save button
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    saveRitual()
                } label: {
                    Text(String(localized: "moon.save"))
                        .font(.custom("Merriweather-Bold", size: 15))
                        .foregroundColor(canSave ? saveButtonLabel : bodyColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSave ? phaseAccent : rowFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(canSave ? Color.clear : rowBorderIdle, lineWidth: 1)
                        )
                }
                .disabled(!canSave || isSaving)
                .padding(.horizontal, 24)

                Spacer(minLength: 8).frame(height: 32)
            }
        }
        .onAppear {
            focusedIndex = 0
            loadExistingLinesIfAny()
        }
    }

    /// On open, try to restore any previously-saved intentions for this phase
    /// today. Guarantees users see their own content across app restarts and
    /// devices. Guards against overwriting content the user has just typed.
    private func loadExistingLinesIfAny() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayKey = df.string(from: Date())

        isLoadingExisting = true
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("moon_rituals").document("\(phase.rawValue)_\(dayKey)")
            .getDocument { snap, err in
                DispatchQueue.main.async {
                    isLoadingExisting = false
                }
                if let err = err {
                    print("⚠️ [MOON_RITUAL] load failed: \(err.localizedDescription)")
                    return
                }
                guard
                    let data = snap?.data(),
                    let savedLines = data["lines"] as? [String],
                    !savedLines.isEmpty
                else { return }

                DispatchQueue.main.async {
                    // If the user has already started typing, do NOT clobber
                    // their in-progress text with stale Firestore data.
                    let userHasTyped = lines.contains { !$0.isEmpty }
                    guard !userHasTyped else { return }

                    var filled: [String] = ["", "", ""]
                    for (i, line) in savedLines.prefix(3).enumerated() {
                        filled[i] = line
                    }
                    lines = filled
                }
            }
    }

    private func saveRitual() {
        guard canSave, !isSaving else { return }
        isSaving = true

        let nonEmpty = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayKey = df.string(from: Date())

        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()

            // Save ritual record (source of truth for the ritual itself)
            let ritualData: [String: Any] = [
                "type": "moon_ritual",
                "phase": phase.rawValue,
                "date": dayKey,
                "lines": nonEmpty,
                "createdAt": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(uid)
                .collection("moon_rituals").document("\(phase.rawValue)_\(dayKey)")
                .setData(ritualData) { err in
                    if let err = err {
                        print("❌ [MOON_RITUAL] save ritual failed: \(err.localizedDescription)")
                    } else {
                        print("✅ [MOON_RITUAL] saved \(phase.rawValue) ritual for \(dayKey) (\(nonEmpty.count) lines)")
                    }
                }

            // Silently mirror intentions into today's daily_recommendation
            // so the backend can use them as personalisation context.
            // Uses merge: true so the doc is created if not yet generated today.
            let recDocID = "\(uid)_\(dayKey)"
            db.collection("daily_recommendation").document(recDocID)
                .setData(["moon_intention": nonEmpty], merge: true) { err in
                    if let err = err {
                        print("❌ [MOON_RITUAL] mirror to daily_recommendation failed: \(err.localizedDescription)")
                    }
                }
        } else {
            print("⚠️ [MOON_RITUAL] no authenticated user — ritual NOT saved to Firestore")
        }

        onComplete()
        dismiss()
    }

}

// MARK: - MoonSymbolView
// Renders a clearly legible moon icon for both phases.
// New moon: crescent + stars (moon.stars.fill, monochrome accent).
// Full moon: custom filled circle so color is fully controlled (avoids SF Symbol disc rendering issues).
private struct MoonSymbolView: View {
    let phase: MoonPhase
    let size: CGFloat
    let accent: Color
    let opacity: Double

    var body: some View {
        Group {
            switch phase {
            case .full:
                // Layered circle: filled disc with a subtle inner glow ring
                ZStack {
                    Circle()
                        .fill(accent.opacity(opacity))
                        .frame(width: size, height: size)
                    Circle()
                        .stroke(accent.opacity(min(opacity + 0.15, 1.0)), lineWidth: size * 0.04)
                        .frame(width: size * 0.75, height: size * 0.75)
                        .blur(radius: 1)
                }
                .frame(width: size, height: size)
            default:
                // Crescent + stars for new moon / fallback
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: size, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(accent.opacity(opacity))
            }
        }
    }
}


