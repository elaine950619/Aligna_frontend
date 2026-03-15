import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit
import FirebaseAuth
import FirebaseFirestore

enum BootPhase {
    case loading
    case onboarding   // ← 新增：需要走新手引导
    case main
}


func currentZodiacSign(for date: Date = Date()) -> String {
    let cal = Calendar(identifier: .gregorian)
    let (m, d) = (cal.component(.month, from: date), cal.component(.day, from: date))
    switch (m, d) {
    case (3,21...31),(4,1...19):  return "♈️ Aries"
    case (4,20...30),(5,1...20):  return "♉️ Taurus"
    case (5,21...31),(6,1...20):  return "♊️ Gemini"
    case (6,21...30),(7,1...22):  return "♋️ Cancer"
    case (7,23...31),(8,1...22):  return "♌️ Leo"
    case (8,23...31),(9,1...22):  return "♍️ Virgo"
    case (9,23...30),(10,1...22): return "♎️ Libra"
    case (10,23...31),(11,1...21):return "♏️ Scorpio"
    case (11,22...30),(12,1...21):return "♐️ Sagittarius"
    case (12,22...31),(1,1...19): return "♑️ Capricorn"
    case (1,20...31),(2,1...18):  return "♒️ Aquarius"
    default:                      return "♓️ Pisces"
    }
}

/// quick-and-pleasant moon phase label (like your React demo)
func currentMoonPhaseLabel(for date: Date = Date()) -> String {
    // Simple ~29.53 day cycle approximation
    let synodic: Double = 29.53058867
    // Anchor: 2000-01-06 18:14 UTC is a known new moon (approx). Good enough for a splash.
    let anchor = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: .init(secondsFromGMT: 0),
        year: 2000, month: 1, day: 6, hour: 18, minute: 14
    ).date!
    
    let days = date.timeIntervalSince(anchor) / 86400
    let phase = (days - floor(days / synodic) * synodic) // [0, synodic)
    switch phase {
    case 0..<1.84566:  return "🌑 New Moon"
    case 1.84566..<5.53699: return "🌒 Waxing Crescent"
    case 5.53699..<9.22831: return "🌓 First Quarter"
    case 9.22831..<12.91963: return "🌔 Waxing Gibbous"
    case 12.91963..<16.61096: return "🌕 Full Moon"
    case 16.61096..<20.30228: return "🌖 Waning Gibbous"
    case 20.30228..<23.99361: return "🌗 Third Quarter"
    case 23.99361..<27.68493: return "🌘 Waning Crescent"
    default: return "🌑 New Moon"
    }
}

// MARK: - Helpers
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexSanitized.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: opacity)
    }
}
// ====== Time & Parse Helpers (新增) ======
struct ISO8601Calendar {
    private static let f1: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let f2: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func date(from s: String) -> Date? { f1.date(from: s) ?? f2.date(from: s) }
}

/// 仅用“本地时区的时分”构造一个 Date（锚定在固定参考日，避免跨时区/日期导致显示漂移）
func makeLocalDate(hour: Int, minute: Int, tz: TimeZone = .current) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    // 选择一个固定参考日（不会用于展示，只为承载时分）
    var comp = DateComponents()
    comp.year = 2000; comp.month = 1; comp.day = 1
    comp.hour = hour; comp.minute = minute
    return cal.date(from: comp)
}

/// 兼容 "HH:mm" / "H:mm" / "h:mm a" / "hh:mm a"
func timeToDateFlexible(_ s: String, tz: TimeZone = .current) -> Date? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let fmts = ["HH:mm","H:mm","h:mm a","hh:mm a","h:mma","hh:mma"]
    for pat in fmts {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = pat
        if let d = f.date(from: trimmed) {
            let cal = Calendar(identifier: .gregorian)
            let hm = cal.dateComponents([.hour,.minute], from: d)
            return makeLocalDate(hour: hm.hour ?? 0, minute: hm.minute ?? 0, tz: tz)
        }
    }
    return nil
}
// 兼容 "yyyy-MM-dd" 和 "yyyy/M/d" 的日期解析（本地时区）
private let DF_YMD: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let DF_YMD_SLASH: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy/M/d"
    return f
}()

@inline(__always)
func parseBirthDateString(_ s: String) -> Date? {
    // 先试 ISO8601（含 T…Z 的情况），再试两种纯日期
    return ISO8601Calendar.date(from: s) ?? DF_YMD.date(from: s) ?? DF_YMD_SLASH.date(from: s)
}



// Subtle text shimmer like your React “brand-title animate-text-shimmer”
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.7), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .blendMode(.screen)
                .mask(content)

            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

// MARK: - LoadingView

struct LoadingView: View {
    var onStartLoading: (() -> Void)? = nil
    var onPersonalComplete: ((Bool) -> Void)? = nil
    private let fixedMessageIndex: Int?

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var didStartLoading = false
    @State private var stage: LoadingStage = .cosmic
    @State private var cosmicEmojiIndex = 0
    @State private var placeEmojiIndex = 0
    @State private var personalIconIndex = 0
    @State private var iconShakePhase: CGFloat = -1
    @State private var dotPhase = 0
    @State private var iconVisible = true
    @State private var autoSkipWorkItem: DispatchWorkItem?
    @State private var autoSkipSecondsRemaining = 0
    @State private var autoSkipTimer: Timer?
    @State private var personalCompleted = false
    @State private var isProcessingPersonal = false
    @State private var didInteractPersonal = false

    @State private var mood: String? = nil
    @State private var stress: String? = nil
    @State private var sleep: String? = nil
    @State private var source: String? = nil

    @State private var sunText: String = "—"
    @State private var moonText: String = "—"
    @State private var risingText: String = "—"
    var locationText: String = "Your Current Location"
    var conditionText: String = "Cloud · Wind · Rain"

    init(
        onStartLoading: (() -> Void)? = nil,
        onPersonalComplete: ((Bool) -> Void)? = nil,
        fixedMessageIndex: Int? = nil
    ) {
        self.onStartLoading = onStartLoading
        self.onPersonalComplete = onPersonalComplete
        self.fixedMessageIndex = fixedMessageIndex
    }

    fileprivate enum LoadingStage: Int {
        case cosmic
        case place
        case personal
    }

    private var anyPersonalSelection: Bool {
        mood != nil || stress != nil || sleep != nil || source != nil
    }

    private var shouldAutoSkipPersonal: Bool {
        !didInteractPersonal
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // === Main content ===
                VStack(spacing: 22) {
                    stageContent
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .onAppear {
                    if !didStartLoading {
                        didStartLoading = true
                        onStartLoading?()
                    }
                }

                VStack {
                    Spacer()
                    if let footer = footerText {
                        Text(footer)
                            .font(.custom("Merriweather-Bold", size: 10))
                            .foregroundColor(themeManager.descriptionText.opacity(0.7))
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                scheduleStageProgression()
                startEmojiTimers()
                if iconShakePhase < 0 {
                    withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                        iconShakePhase = 1
                    }
                }
                startDotTimer()
                startIconFadeTimer()
                fetchChartDataFromFirestore()
            }
            .onChange(of: stage, initial: false) { _, newStage in
                if newStage == .personal {
                    loadPersonalSelections()
                    scheduleAutoSkipIfNeeded()
                }
            }
            .onChange(of: didInteractPersonal, initial: false) { _, interacted in
                if interacted {
                    autoSkipWorkItem?.cancel()
                    autoSkipTimer?.invalidate()
                    autoSkipSecondsRemaining = 0
                }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
        }
    }

    private var stageContent: some View {
        let headerHeight: CGFloat = 120
        let contentHeight: CGFloat = 240
        return VStack(spacing: 12) {
            switch stage {
            case .cosmic:
                stageHeader(title: "Cosmic signals",
                            subtitle: cosmicSubtitle,
                            iconName: cosmicIcons[cosmicEmojiIndex],
                            topPadding: 0)
                    .frame(height: headerHeight + contentHeight, alignment: .top)

            case .place:
                stageHeader(title: "Place signals",
                            subtitle: placeSubtitle,
                            iconName: placeIcons[placeEmojiIndex],
                            topPadding: 0)
                    .frame(height: headerHeight + contentHeight, alignment: .top)

            case .personal:
                stageHeader(title: "Personal check-in",
                            subtitle: "Tap what feels true right now.",
                            iconName: personalIcons[personalIconIndex],
                            topPadding: 6)
                    .frame(height: headerHeight, alignment: .top)
                VStack(spacing: 8) {
                    personalCheckIn
                    if personalCompleted {
                        Text("Logged for today.")
                            .font(AlignaType.helperSmall())
                            .foregroundColor(themeManager.descriptionText.opacity(0.9))
                    }
                }
                .frame(height: contentHeight, alignment: .top)
                .padding(.top, 28)
            }
        }
    }

    private func stageHeader(title: String, subtitle: String, iconName: String, topPadding: CGFloat) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 20))
                .foregroundColor(themeManager.primaryText)
            iconView(iconName, size: 56)
                .opacity(iconVisible ? 1.0 : 0.35)
                .offset(x: iconShakePhase * 2, y: iconShakePhase * -1)
                .animation(.easeInOut(duration: 0.35), value: iconVisible)
            Text(subtitle)
                .font(AlignaType.helperSmall())
                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                .multilineTextAlignment(.center)
            if stage != .personal {
                loadingDots
            }
        }
        .padding(.top, topPadding)
    }


    private func iconView(_ iconName: String, size: CGFloat) -> some View {
        Image(systemName: iconName)
            .font(.system(size: size))
            .foregroundColor(themeManager.primaryText)
            .frame(width: size, height: size, alignment: .center)
            .textSelection(.disabled)
    }

    private var loadingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(themeManager.primaryText.opacity(dotPhase == index ? 0.9 : 0.25))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.top, 2)
    }

    private var personalCheckIn: some View {
        VStack(spacing: 6) {
            compactRow(
                title: "Mood",
                options: [("sun.max.fill", "Joy"), ("flame.fill", "Anger"), ("cloud.rain.fill", "Grief"), ("leaf.fill", "Calm")],
                selection: $mood
            )
            compactRow(
                title: "Stress",
                options: [("minus.circle", "Low"), ("equal.circle", "Med"), ("plus.circle", "High"), ("bolt.circle", "Peak")],
                selection: $stress
            )
            compactRow(
                title: "Sleep",
                options: [("bed.double.fill", "Poor"), ("moon.zzz.fill", "OK"), ("sun.max.fill", "Great"), ("zzz", "Rest")],
                selection: $sleep
            )
            compactRow(
                title: "Emotional Source",
                options: [("briefcase.fill", "Work"), ("person.2.fill", "People"), ("heart.fill", "Health"), ("dollarsign.circle.fill", "Money")],
                selection: $source
            )
            Button {
                didInteractPersonal = true
                isProcessingPersonal = true
                completePersonal()
            } label: {
                HStack(spacing: 8) {
                    if isProcessingPersonal {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(themeManager.isNight ? Color.black : Color.white)
                            .scaleEffect(0.75)
                    }
                    Text(isProcessingPersonal ? "Processing…" : primaryActionLabel)
                }
                .font(.custom("Merriweather-Bold", size: 13))
                .foregroundColor(themeManager.isNight ? Color.black : Color.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(themeManager.primaryText)
                .cornerRadius(13)
            }
            .disabled(isProcessingPersonal)
            .padding(.top, 2)
        }
    }

    private func compactRow(
        title: String,
        options: [(String, String)],
        selection: Binding<String?>
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 15))
                .foregroundColor(themeManager.primaryText.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(options, id: \.1) { option in
                    Button {
                        didInteractPersonal = true
                        selection.wrappedValue = option.1
                    } label: {
                        VStack(spacing: 6) {
                            iconView(option.0, size: 14)
                                .foregroundColor(themeManager.primaryText)
                            Text(option.1)
                                .font(.custom("Merriweather-Bold", size: 10))
                                .foregroundColor(themeManager.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selection.wrappedValue == option.1 ? themeManager.primaryText.opacity(0.14) : Color.white.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(themeManager.primaryText.opacity(0.22), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var cosmicIcons: [String] { ["sun.max.fill", "moon.stars.fill", "sparkles", "sparkle"] }
    private var placeIcons: [String] { ["cloud.rain.fill", "wind", "cloud.fill", "water.waves", "tree.fill"] }
    private var personalIcons: [String] { ["person.circle", "person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.2.circle"] }

    private var footerText: String? {
        switch stage {
        case .cosmic:
            return "Astronomical observations are sourced from NOAA and NASA."
        case .place:
            return "Environmental observations are sourced from NASA and ESA."
        case .personal:
            return nil
        }
    }

    private var cosmicSubtitle: String {
        return "Sun: \(sunText) · Moon: \(moonText) · Rising: \(risingText)"
    }

    private var placeSubtitle: String {
        let lines = [
            "Wind, rain, and light are moving",
            "Water, air, and temperature shift with you",
            "Reading today’s living atmosphere"
        ]
        let base = lines[placeEmojiIndex % lines.count]
        return "\(base) · \(locationText) · \(conditionText)"
    }

    private func scheduleStageProgression() {
        guard fixedMessageIndex == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if stage == .cosmic { stage = .place }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            if stage == .place { stage = .personal }
        }
    }

    private func startEmojiTimers() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            cosmicEmojiIndex = (cosmicEmojiIndex + 1) % cosmicIcons.count
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            placeEmojiIndex = (placeEmojiIndex + 1) % placeIcons.count
        }
        Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
            personalIconIndex = (personalIconIndex + 1) % personalIcons.count
        }
    }

    private func startDotTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }

    private func startIconFadeTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
            iconVisible.toggle()
        }
    }

    private func fetchChartDataFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("chartData").document(uid).getDocument { snap, _ in
            guard let data = snap?.data(),
                  let chartData = data["chartData"] as? [String: Any] else { return }

            let sun = (chartData["sun"] as? String ?? chartData["sunSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let moon = (chartData["moon"] as? String ?? chartData["moonSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rising = (chartData["ascendant"] as? String ?? chartData["ascendantSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                if !sun.isEmpty { sunText = sun }
                if !moon.isEmpty { moonText = moon }
                if !rising.isEmpty { risingText = rising }
            }
        }
    }

    private var dateStringForQuery: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func normalizedSelection(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func savePersonalSelections() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ds = dateStringForQuery
        let db = Firestore.firestore()

        let payload: [String: Any] = [
            "mood": normalizedSelection(mood) ?? "",
            "stress": normalizedSelection(stress) ?? "",
            "sleep": normalizedSelection(sleep) ?? "",
            "emotionalSource": normalizedSelection(source) ?? "",
            "updatedAt": Timestamp()
        ]

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let recDoc = snapshot?.documents.first {
                    let recID = recDoc.documentID
                    let journalsRef = db.collection("daily_recommendation")
                        .document(recID)
                        .collection("journals")
                    journalsRef.order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { journSnap, _ in
                            if let journDoc = journSnap?.documents.first {
                                journalsRef.document(journDoc.documentID)
                                    .setData(payload, merge: true)
                            } else {
                                journalsRef.addDocument(data: payload.merging([
                                    "createdAt": Timestamp()
                                ]) { $1 })
                            }
                        }
                }
            }

        db.collection("users").document(uid)
            .collection("journals").document(ds)
            .setData(payload, merge: true)
    }

    private func loadPersonalSelections() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ds = dateStringForQuery
        let db = Firestore.firestore()

        func applySelections(from data: [String: Any]) {
            func nonEmptyString(_ key: String) -> String? {
                let raw = data[key] as? String ?? ""
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            mood = nonEmptyString("mood")
            stress = nonEmptyString("stress")
            sleep = nonEmptyString("sleep")
            source = nonEmptyString("emotionalSource")
        }

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let recDoc = snapshot?.documents.first {
                    db.collection("daily_recommendation")
                        .document(recDoc.documentID)
                        .collection("journals")
                        .order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { journSnap, _ in
                            if let journDoc = journSnap?.documents.first {
                                DispatchQueue.main.async {
                                    applySelections(from: journDoc.data())
                                }
                            }
                        }
                } else {
                    db.collection("users").document(uid)
                        .collection("journals").document(ds)
                        .getDocument { doc, _ in
                            DispatchQueue.main.async {
                                applySelections(from: doc?.data() ?? [:])
                            }
                        }
                }
            }
    }

    private func scheduleAutoSkipIfNeeded() {
        autoSkipWorkItem?.cancel()
        autoSkipTimer?.invalidate()

        let totalSeconds = 3
        autoSkipSecondsRemaining = totalSeconds
        autoSkipTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            autoSkipSecondsRemaining = max(0, autoSkipSecondsRemaining - 1)
            if autoSkipSecondsRemaining == 0 {
                timer.invalidate()
            }
        }

        let item = DispatchWorkItem {
            if shouldAutoSkipPersonal {
                DispatchQueue.main.async {
                    isProcessingPersonal = true
                    completePersonal()
                }
            }
        }
        autoSkipWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(totalSeconds), execute: item)
    }

    private var primaryActionLabel: String {
        if didInteractPersonal {
            return "Continue"
        }
        if autoSkipSecondsRemaining > 0 {
            return "Skip in \(autoSkipSecondsRemaining)s"
        }
        return "Continue"
    }

    private func completePersonal() {
        guard !personalCompleted else { return }
        autoSkipWorkItem?.cancel()
        autoSkipTimer?.invalidate()
        autoSkipSecondsRemaining = 0
        personalCompleted = true

        let didModify = didInteractPersonal
        if didModify {
            savePersonalSelections()
        }
        onPersonalComplete?(didModify)
    }
}


#if DEBUG
private extension LoadingView {
    init(previewStage: LoadingStage) {
        self.init(onStartLoading: nil, onPersonalComplete: nil, fixedMessageIndex: 0)
        _stage = State(initialValue: previewStage)
        if previewStage == .personal {
            _autoSkipSecondsRemaining = State(initialValue: 3)
        }
    }
}

private struct LoadingViewPreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    let isNight: Bool
    let stage: LoadingView.LoadingStage

    init(isNight: Bool = false, stage: LoadingView.LoadingStage) {
        self.isNight = isNight
        self.stage = stage
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        LoadingView(previewStage: stage)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Loading Cosmic") {
    LoadingViewPreviewContainer(stage: .cosmic)
}

#Preview("Loading Place") {
    LoadingViewPreviewContainer(stage: .place)
}

#Preview("Loading Personal") {
    LoadingViewPreviewContainer(stage: .personal)
}

#Preview("Loading Night") {
    LoadingViewPreviewContainer(isNight: true, stage: .cosmic)
}
#endif
