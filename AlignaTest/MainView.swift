import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit
import UIKit

enum AlynnaAppGroup {
    static let id = "group.martinyuan.AlynnaTest"
}

struct AlynnaWidgetSnapshot: Codable, Hashable {
    var savedAt: Date
    var mantra: String
    var locationName: String
    var sunSign: String
    var moonSign: String
    var risingSign: String
    var weatherSummary: String
    var weatherDetailSummary: String
    var environmentSummary: String
    var soundKey: String
    var soundTitle: String
    var colorKey: String
    var colorTitle: String
    var colorHex: String?
    var placeKey: String
    var placeTitle: String
    var gemstoneKey: String
    var gemstoneTitle: String
    var scentKey: String
    var scentTitle: String
    var activityKey: String
    var activityTitle: String
    var careerKey: String
    var careerTitle: String
    var relationshipKey: String
    var relationshipTitle: String
    var categoryReasoning: [String: String]
    var reasoningSummary: String

    init(
        mantra: String,
        locationName: String = "",
        sunSign: String = "",
        moonSign: String = "",
        risingSign: String = "",
        weatherSummary: String = "",
        weatherDetailSummary: String = "",
        environmentSummary: String = "",
        soundKey: String = "",
        soundTitle: String = "",
        colorKey: String = "",
        colorTitle: String,
        colorHex: String? = nil,
        placeKey: String = "",
        placeTitle: String,
        gemstoneKey: String = "",
        gemstoneTitle: String,
        scentKey: String = "",
        scentTitle: String,
        activityKey: String = "",
        activityTitle: String = "",
        careerKey: String = "",
        careerTitle: String = "",
        relationshipKey: String = "",
        relationshipTitle: String = "",
        categoryReasoning: [String: String] = [:],
        reasoningSummary: String = "",
        savedAt: Date = Date()
    ) {
        self.savedAt = savedAt
        self.mantra = mantra
        self.locationName = locationName
        self.sunSign = sunSign
        self.moonSign = moonSign
        self.risingSign = risingSign
        self.weatherSummary = weatherSummary
        self.weatherDetailSummary = weatherDetailSummary
        self.environmentSummary = environmentSummary
        self.soundKey = soundKey
        self.soundTitle = soundTitle
        self.colorKey = colorKey
        self.colorTitle = colorTitle
        self.colorHex = colorHex
        self.placeKey = placeKey
        self.placeTitle = placeTitle
        self.gemstoneKey = gemstoneKey
        self.gemstoneTitle = gemstoneTitle
        self.scentKey = scentKey
        self.scentTitle = scentTitle
        self.activityKey = activityKey
        self.activityTitle = activityTitle
        self.careerKey = careerKey
        self.careerTitle = careerTitle
        self.relationshipKey = relationshipKey
        self.relationshipTitle = relationshipTitle
        self.categoryReasoning = categoryReasoning
        self.reasoningSummary = reasoningSummary
    }
}

private let widgetSnapshotKey = "alynna.widget.snapshot"

enum AlynnaWidgetStore {
    static func save(_ snapshot: AlynnaWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: AlynnaAppGroup.id) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: widgetSnapshotKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

func getAddressFromCoordinate(
    _ coordinate: CLLocationCoordinate2D,
    preferredLocale: Locale = Locale(identifier: "en_US"),
    completion: @escaping (String?) -> Void
) {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    func humanReadable(from p: CLPlacemark) -> String? {
        let candidates: [String?] = [
            p.locality,
            p.subLocality,
            p.administrativeArea,
            p.subAdministrativeArea,
            p.name,
            p.country
        ]

        if let picked = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty && !isCoordinateLikeString($0) }) {
            return picked
        }
        return nil
    }

    func reverse(allowRetry: Bool) {
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
            if let p = placemarks?.first, let name = humanReadable(from: p) {
                completion(name)
                return
            }
            if let e = error as? CLError, e.code == .geocodeFoundNoResult, allowRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    reverse(allowRetry: false)
                }
                return
            }
            completion(nil)
        }
    }

    reverse(allowRetry: true)
}

func isCoordinateLikeString(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = #"^\s*-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$"#
    return trimmed.range(of: pattern, options: .regularExpression) != nil
}

enum AlignaType {
    static func logo() -> Font { .custom("Merriweather-Black", size: 50) }
    static func brandTitle() -> Font { .custom("Merriweather-Black", size: 34) }
    static func expandedMantraBoldItalic() -> Font { .custom("Merriweather-Bold", size: 23) }

    // Language-aware mantra fonts: use Source Han Serif SC for Chinese, Merriweather for Latin
    static func expandedMantraFont() -> Font {
        currentRecommendationLanguageCode() == "zh-Hans"
            ? .custom("Source Han Serif SC VF", size: 22).weight(.bold)
            : .custom("Merriweather-Bold", size: 23)
    }
    static func homeMantraFont() -> Font {
        currentRecommendationLanguageCode() == "zh-Hans"
            ? .custom("Source Han Serif SC VF", size: 18).weight(.bold)
            : .custom("Merriweather-Italic", size: 18)
    }
    static func wallpaperMantraFont() -> Font {
        currentRecommendationLanguageCode() == "zh-Hans"
            ? .custom("Source Han Serif SC VF", size: 20).weight(.bold)
            : .system(size: 20, weight: .semibold, design: .serif)
    }

    static func homeSubtitle() -> Font { .custom("Merriweather-Italic", size: 18) }

    static func gridCategoryTitle() -> Font { .custom("Merriweather-Bold", size: 18) }
    static func gridItemName() -> Font { .custom("Merriweather-Light", size: 16) }

    static func loadingSubtitle() -> Font { .custom("Merriweather-Italic", size: 16) }
    static func helperSmall() -> Font { .custom("Merriweather-Light", size: 14) }

    static let logoLineSpacing: CGFloat = 44 - 38
    static let descLineSpacing: CGFloat = 26 - 18
    static let body16LineSpacing: CGFloat = 22 - 16
    static let small14LineSpacing: CGFloat = 20 - 14
}

struct SafeImage: View {
    let name: String
    let renderingMode: Image.TemplateRenderingMode?
    let contentMode: ContentMode

    init(
        name: String,
        renderingMode: Image.TemplateRenderingMode? = .template,
        contentMode: ContentMode = .fit
    ) {
        self.name = name
        self.renderingMode = renderingMode
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .renderingMode(renderingMode)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
                    .opacity(0.5)
            }
        }
        .accessibilityLabel(Text(name.isEmpty ? "image" : name))
    }
}

private struct MantraFocus: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var createdAt: Date
}

private struct FocusedMantraEntry: Codable, Hashable {
    var mantra: String
    var recommendations: [String: String]
    var reasoningSummary: String
    var howToEngage: [String: String]
    var locationName: String
    var savedAt: Date
    var isDefault: Bool

    init(
        mantra: String,
        recommendations: [String: String],
        reasoningSummary: String,
        howToEngage: [String: String] = [:],
        locationName: String,
        savedAt: Date,
        isDefault: Bool
    ) {
        self.mantra = mantra
        self.recommendations = recommendations
        self.reasoningSummary = reasoningSummary
        self.howToEngage = howToEngage
        self.locationName = locationName
        self.savedAt = savedAt
        self.isDefault = isDefault
    }

    private enum CodingKeys: String, CodingKey {
        case mantra
        case recommendations
        case reasoningSummary
        case howToEngage
        case locationName
        case savedAt
        case isDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mantra = try container.decode(String.self, forKey: .mantra)
        recommendations = try container.decode([String: String].self, forKey: .recommendations)
        reasoningSummary = try container.decode(String.self, forKey: .reasoningSummary)
        howToEngage = try container.decodeIfPresent([String: String].self, forKey: .howToEngage) ?? [:]
        locationName = try container.decode(String.self, forKey: .locationName)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mantra, forKey: .mantra)
        try container.encode(recommendations, forKey: .recommendations)
        try container.encode(reasoningSummary, forKey: .reasoningSummary)
        try container.encode(howToEngage, forKey: .howToEngage)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(isDefault, forKey: .isDefault)
    }
}

private struct DailyFocusUsageEntry: Codable, Hashable {
    var generatedFocuses: [String: Int]
}

struct MainView: View {
    private enum FocusFormField: Hashable {
        case name
        case description
    }

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var soundPlayer: SoundPlayer
    @EnvironmentObject var reasoningStore: DailyReasoningStore
    @EnvironmentObject var locationPermissionCoordinator: LocationPermissionCoordinator
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("lastRecommendationPlace") var lastRecommendationPlace: String = ""   // ✅ NEW
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("lastCurrentPlaceUpdate") var lastCurrentPlaceUpdate: String = ""
    @AppStorage("todayFetchLock") private var todayFetchLock: String = ""
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("didDeleteAccount") private var didDeleteAccount: Bool = false
    @AppStorage("dailyMantraNotificationEnabled") private var dailyMantraNotificationEnabled: Bool = false
    @AppStorage("dailyMantraNotificationHour") private var dailyMantraNotificationHour: Int = 7
    @AppStorage("dailyMantraNotificationMinute") private var dailyMantraNotificationMinute: Int = 10
    @AppStorage("dailyRhythmUpdateHour") private var dailyRhythmUpdateHour: Int = 7
    @AppStorage("dailyRhythmUpdateMinute") private var dailyRhythmUpdateMinute: Int = 0
    @AppStorage("cachedDailyMantra") private var cachedDailyMantra: String = ""
    @AppStorage("lastRecommendationTimestamp") private var lastRecommendationTimestamp: Double = 0
    @AppStorage("lastRecommendationHasFullSet") private var lastRecommendationHasFullSet: Bool = false
    @AppStorage("lastManualRefreshTimestamp") private var lastManualRefreshTimestamp: Double = 0
    @AppStorage("shouldExpandMantraOnBoot") private var shouldExpandMantraOnBoot: Bool = false
    @AppStorage("shouldExpandMantraFromNotification") private var shouldExpandMantraFromNotification: Bool = false
    @AppStorage("mantraExpandHapticDay") private var mantraExpandHapticDay: String = ""
    @AppStorage("mantraGuidanceHintTapCount") private var mantraGuidanceHintTapCount: Int = 0
    @AppStorage("widgetLocationName") private var widgetLocationName: String = ""
    @AppStorage("widgetSunSign") private var widgetSunSign: String = ""
    @AppStorage("widgetMoonSign") private var widgetMoonSign: String = ""
    @AppStorage("widgetRisingSign") private var widgetRisingSign: String = ""
    @AppStorage("widgetWeatherSummary") private var widgetWeatherSummary: String = ""
    @AppStorage("widgetWeatherDetailSummary") private var widgetWeatherDetailSummary: String = ""
    @AppStorage("widgetEnvironmentSummary") private var widgetEnvironmentSummary: String = ""
    @AppStorage("mantraTagLibraryStorage") private var mantraTagLibraryStorage: String = ""
    @AppStorage("mantraTagSelectionsStorage") private var mantraTagSelectionsStorage: String = ""
    @AppStorage("mantraFocusCacheStorage") private var mantraFocusCacheStorage: String = ""
    @AppStorage("mantraActiveFocusStorage") private var mantraActiveFocusStorage: String = ""
    @AppStorage("mantraFocusUsageStorage") private var mantraFocusUsageStorage: String = ""
    @AppStorage("hasDismissedFocusHelper") private var hasDismissedFocusHelper: Bool = false
    // legacy focus 迁移只执行一次的标记
    @AppStorage("hasCompletedLegacyFocusMigration") private var hasCompletedLegacyFocusMigration: Bool = false
    @State private var isFetchingToday: Bool = false
    
    @State private var isMantraExpanded: Bool = false
    @State private var showGridItems: Bool = false
    @State private var showTodaySoundPlayer: Bool = false
    @State private var isAutoDismissSoundPlayer = false
    @State private var soundPlayerAutoDismissTask: Task<Void, Never>? = nil
    @State private var showNoSoundToast: Bool = false
    @State private var journalSpinAngle: Double = 0
    @State private var lastPrefetchedSoundKey: String = ""
    @State private var mantraSaveMessage: String = ""

    @State private var showReasoningBubble: Bool = false
    @State private var refreshCooldownMessage = ""
    @State private var isManualRefreshFlow = false

    @AppStorage("todayAutoRefetchDone") private var todayAutoRefetchDone: String = ""
    @AppStorage("shouldShowBootLoading") private var shouldShowBootLoading: Bool = false
    @AppStorage("showMainGenerationOverlay") private var showMainGenerationOverlay: Bool = false
    @AppStorage("mainGenerationOverlayTitle") private var mainGenerationOverlayTitle: String = "Generating today's mantra"
    @AppStorage("mainGenerationOverlayMessage") private var mainGenerationOverlayMessage: String = "We're weaving together your cosmic, environmental, and personal signals."

    @State private var autoRefetchScheduled = false

    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var authWaitTimedOut = false
    @State private var didResolveBootPath = false
    @State private var isBootDataReady = false
    @State private var didCompletePersonalCheckIn = false
    @State private var pendingMantraExpansion = false
    @State private var isMantraReady = false
    @State private var isGenerationInProgress = false
    @State private var isUsingPreviousResult = false
    @State private var showGenerationToast = false
    @State private var generationToastMessage = ""
    @State private var showGenerationStrongHint = false
    @State private var generationOverlaySequence: Int = 0
    @State private var isDefaultRecommendation = false
    @State private var pendingGenerationToast = false
    @State private var showReasoningSheet = false
    @State private var showWallpaperPreview = false
    @State private var showFocusManagerSheet = false
    @State private var showFocusHint = false
    @State private var showNewFocusForm = false
    @State private var mantraFocuses: [MantraFocus] = []
    @State private var mantraFocusSelections: [String: [String]] = [:]
    @State private var mantraFocusCache: [String: [String: FocusedMantraEntry]] = [:]
    @State private var mantraActiveFocusByDay: [String: String] = [:]
    @State private var focusGenerationTagID: String? = nil
    @State private var previousActiveFocusIDBeforeFocusRequest: String? = nil
    @State private var newFocusName: String = ""
    @State private var newFocusDescription: String = ""
    @State private var focusManagerMessage: String = ""
    @State private var focusManagerMessageIsError = false
    @State private var mainViewDialogTitle: String = ""
    @State private var mainViewDialogMessage: String = ""
    @State private var mainViewDialogSymbol: String = "exclamationmark.circle"
    @State private var showMainViewDialog = false
    @State private var mainViewDialogPrimaryButtonTitle: String? = nil
    @State private var mainViewDialogPrimaryAction: (() -> Void)? = nil
    @State private var mainViewDialogIsLocationPermission = false
    @State private var mainViewDialogTone: AlynnaDialogTone = .info
    @State private var pendingFocusDeletion: MantraFocus? = nil
    @State private var hasLoadedMantraFocuses = false
    @State private var mantraFocusUsageByDay: [String: DailyFocusUsageEntry] = [:]
    @FocusState private var focusedFocusFormField: FocusFormField?

    @AppStorage("watchdogDay") private var watchdogDay: String = ""
    @AppStorage("todayAutoRefetchAttempts") private var todayAutoRefetchAttempts: Int = 0
    // NEW: 多次重试的配置
    private let maxRefetchAttempts = 3
    private let initialRefetchDelay: TimeInterval = 8.0

    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
    @State private var selectedDate = Date()
    @State private var mainNavigationPath = NavigationPath()
    
    @State private var bootPhase: BootPhase = .loading
    
    @State private var didBootVisuals = false
    @State private var shouldCollapseMantraOnReturn = false
    @State private var privilegedNickname: String = ""

    private var hasRecentRecommendation: Bool {
        guard lastRecommendationHasFullSet else { return false }
        guard !isDefaultRecommendation else { return false }
        let recDay = effectiveDayString(for: Date(timeIntervalSince1970: lastRecommendationTimestamp))
        return recDay == todayString()
    }

    private var isPrivilegedUser: Bool {
        let candidates = [privilegedNickname, viewModel.nickname]
        return candidates.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "jakobzhao"
        }
    }

    private var shouldShowMantraGuidanceHint: Bool {
        isMantraExpanded && mantraGuidanceHintTapCount < 3
    }

    private let colorHexMapping: [String:String] = [
        "amber":"#FFBF00", "cream":"#FFFDD0", "forest_green":"#228B22",
        "ice_blue":"#ADD8E6", "indigo":"#4B0082", "rose":"#FF66CC",
        "sage_green":"#9EB49F", "silver_white":"#C0C0C0", "slate_blue":"#6A5ACD",
        "teal":"#008080"
    ]
    private let maxAppliedFocuses = 3
    private let dailyFocusID = "11111111-1111-1111-1111-111111111111"
    private let fertilityFocusID = "22222222-2222-2222-2222-222222222222"
    private let connectionFocusID = "33333333-3333-3333-3333-333333333333"
    private let transitionFocusID = "44444444-4444-4444-4444-444444444444"
    private let caregivingFocusID = "55555555-5555-5555-5555-555555555555"
    private let recoveryFocusID = "66666666-6666-6666-6666-666666666666"
    private let clarityFocusID = "77777777-7777-7777-7777-777777777777"
    private let griefFocusID = "88888888-8888-8888-8888-888888888888"
    private let maxNonDailyFocusUpdatesPerDay = 2

    private var currentFocusSelectionKey: String {
        todayString()
    }

    private var appliedMantraFocusIDs: [String] {
        mantraFocusSelections[currentFocusSelectionKey] ?? []
    }

    private var mantraFocusLookup: [String: MantraFocus] {
        Dictionary(uniqueKeysWithValues: mantraFocuses.map { ($0.id.uuidString, $0) })
    }

    private var appliedMantraFocuses: [MantraFocus] {
        appliedMantraFocusIDs.compactMap { mantraFocusLookup[$0] }
    }

    private var canApplyMoreFocuses: Bool {
        appliedMantraFocusIDs.count < maxAppliedFocuses
    }

    private var canSaveNewFocus: Bool {
        !normalizedFocusText(newFocusName).isEmpty && !normalizedFocusText(newFocusDescription).isEmpty
    }

    private var activeFocusID: String {
        if let stored = mantraActiveFocusByDay[currentFocusSelectionKey], mantraFocusLookup[stored] != nil {
            return stored
        }
        return dailyFocusID
    }

    private var activeFocus: MantraFocus? {
        mantraFocusLookup[activeFocusID]
    }

    private var activeFocusName: String {
        activeFocus?.name.lowercased() ?? "daily"
    }

    private var normalizedGender: String {
        viewModel.gender.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var normalizedRelationshipStatus: String {
        viewModel.relationshipStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var userAge: Int? {
        let years = Calendar.current.dateComponents([.year], from: viewModel.birth_date, to: Date()).year
        guard let years, years > 0 else { return nil }
        return years
    }

    private var todayFocusUsage: DailyFocusUsageEntry {
        mantraFocusUsageByDay[currentFocusSelectionKey] ?? DailyFocusUsageEntry(generatedFocuses: [:])
    }

    private var shouldShowCompactFocusBadge: Bool {
        !isMantraExpanded && activeFocusName != "daily"
    }

    init(
        previewExpanded: Bool = false,
        previewShowGeneration: Bool = false,
        previewToastMessage: String? = nil,
        previewShowStrongHint: Bool = false,
        previewUsingPreviousResult: Bool = false
    ) {
        _isMantraExpanded = State(initialValue: previewExpanded)
        _isMantraReady = State(initialValue: previewExpanded)
        _isGenerationInProgress = State(initialValue: previewShowGeneration)
        _showGenerationToast = State(initialValue: previewToastMessage != nil)
        _generationToastMessage = State(initialValue: previewToastMessage ?? "")
        _showGenerationStrongHint = State(initialValue: previewShowStrongHint)
        _isUsingPreviousResult = State(initialValue: previewUsingPreviousResult)
    }

    private func todayColorHex() -> String? {
        let key = viewModel.recommendations["Color"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return colorHexMapping[key]
    }

    private func ensureDefaultsIfMissing() {
        // If nothing loaded yet, supply local demo content
        if viewModel.recommendations.isEmpty {
            if !isGenerationInProgress {
                viewModel.recommendations = DesignRecs.docs
                viewModel.dailyMantra = viewModel.dailyMantra.isEmpty ? DesignRecs.mantra : viewModel.dailyMantra
            }
        }
        if viewModel.dailyMantra.isEmpty, !cachedDailyMantra.isEmpty {
            viewModel.dailyMantra = cachedDailyMantra
        }
        // If we don’t have human-facing titles yet, use local titles
        if recommendationTitles.isEmpty {
            recommendationTitles = DesignRecs.titles
        }
    }
    
    private var updatedOnText: String {
        let date = lastRecommendationDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = date.isEmpty ? todayString() : date

        let p = (lastRecommendationPlace.isEmpty ? viewModel.currentPlace : lastRecommendationPlace)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if p.isEmpty {
            return "\(String(localized: "main.updated_on")) \(dateText)"
        } else {
            return "\(String(localized: "main.updated_on")) \(dateText), \(p)"
        }
    }
    private var updatedOnFooterText: String {
        updatedOnText.replacingOccurrences(of: String(localized: "main.updated_on"), with: String(localized: "main.updated_on").lowercased())
    }

    private var todaySoundKey: String {
        viewModel.recommendations["Sound"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isTodaySoundPlaying: Bool {
        !todaySoundKey.isEmpty
            && soundPlayer.isPlaying
            && soundPlayer.currentSoundKey == todaySoundKey
    }

    private var isTodaySoundLoading: Bool {
        !todaySoundKey.isEmpty
            && soundPlayer.isLoading
            && soundPlayer.currentSoundKey == todaySoundKey
    }

    private var noSoundToastView: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("detail.no_sound")
                .font(.custom("Merriweather-Regular", size: 12))
        }
        .foregroundColor(themeManager.primaryText.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .accessibilityLabel("No sound recommendation")
    }

    private var generationStatusText: String? {
        guard isGenerationInProgress else { return nil }
        if let focusGenerationTagID,
           let focus = mantraFocusLookup[focusGenerationTagID] {
            return "Generating your \(focus.name) focus mantra."
        }
        if isUsingPreviousResult {
            return String(localized: "focus.previous_result")
        }
        return showGenerationStrongHint
            ? String(localized: "loading.generating_mantra_progress")
            : String(localized: "loading.generating_mantra")
    }

    private var focusHelperText: String {
        return !hasDismissedFocusHelper
            ? String(localized: "focus.choose_focuses")
            : ""
    }

    private var focusHelperShowsProgress: Bool {
        false
    }

    private var shouldShowFocusHelper: Bool {
        !focusHelperText.isEmpty
    }

    private func dismissFocusHelperIfNeeded() {
        guard !hasDismissedFocusHelper else { return }
        hasDismissedFocusHelper = true
    }

    private func configureDailyGenerationOverlay() {
        mainGenerationOverlayTitle = "Generating today's mantra"
        mainGenerationOverlayMessage = "We're weaving together your cosmic, environmental, and personal signals."
    }

    private func configureFocusGenerationOverlay(for focusName: String) {
        mainGenerationOverlayTitle = "Generating your focus mantra"
        mainGenerationOverlayMessage = "We're shaping a mantra around \(focusName) and today's signals."
    }

    private func scheduleGenerationOverlayHints() {
        generationOverlaySequence += 1
        let sequence = generationOverlaySequence
        let isFocusGeneration = focusGenerationTagID != nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            guard generationOverlaySequence == sequence, isGenerationInProgress else { return }
            showGenerationStrongHint = true
            mainGenerationOverlayMessage = isFocusGeneration
                ? "Holding tight. Focus mantra requests can take up to a minute."
                : "Holding tight. Generating today's mantra can take up to a minute."
        }
    }

    private var hasRefreshedAlignmentToday: Bool {
        guard lastManualRefreshTimestamp > 0 else { return false }
        let refreshedDay = effectiveDayString(for: Date(timeIntervalSince1970: lastManualRefreshTimestamp))
        return refreshedDay == todayString()
    }

    private var rhythmHeaderSubtitle: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "EEEE, MMMM d"

        let dateText = dateFormatter.string(from: Date())
        let locationText = resolvedWidgetLocation()
        let updateTimeText = isManualRefreshFlow
            ? timeText(for: Date())
            : (lastRecommendationTimeText ?? timeText(for: Date()))

        if locationText.isEmpty {
            return "Last update: \(dateText), \(updateTimeText)"
        }

        return "Last update: \(dateText), \(updateTimeText) at \(locationText)"
    }

    private func effectiveDayString(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = .current

        let currentComponents = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        let updateMinutes = dailyRhythmUpdateHour * 60 + dailyRhythmUpdateMinute

        let effectiveDate: Date
        if currentMinutes < updateMinutes {
            effectiveDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            effectiveDate = date
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: effectiveDate)
    }

    private var derivedNotificationTime: (hour: Int, minute: Int) {
        let totalMinutes = (dailyRhythmUpdateHour * 60 + dailyRhythmUpdateMinute + 10) % (24 * 60)
        return (totalMinutes / 60, totalMinutes % 60)
    }

    private func syncNotificationTimeToRhythmUpdate() {
        let schedule = derivedNotificationTime
        dailyMantraNotificationHour = schedule.hour
        dailyMantraNotificationMinute = schedule.minute
    }

    private var infoIconButton: some View {
        Button {
            showReasoningSheet = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.primaryText)
                .opacity(0.72)
                // 扩大点击区域，确保易于点击
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "main.why_mantra"))
        .disabled(viewModel.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(viewModel.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
    }

    private var expandedMantraInfoBadge: some View {
        infoIconButton
            .accessibilityHint("Shows why this mantra was chosen")
    }

    private var mainViewDialog: some View {
        AlynnaActionDialog(
            title: mainViewDialogTitle,
            message: mainViewDialogMessage,
            symbol: mainViewDialogSymbol,
            tone: mainViewDialogTone,
            primaryButtonTitle: mainViewDialogPrimaryButtonTitle,
            primaryAction: mainViewDialogPrimaryAction,
            dismissButtonTitle: mainViewDialogPrimaryButtonTitle == nil ? "OK" : "Cancel",
            onDismiss: dismissMainViewDialog
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(20)
    }

    private func expandedMantraLastLineRect(for text: String, width: CGFloat) -> CGRect? {
        let font: UIFont
        if currentRecommendationLanguageCode() == "zh-Hans" {
            // Source Han Serif SC VF is a variable font; use descriptor with bold weight
            let descriptor = UIFontDescriptor(fontAttributes: [
                .name: "SourceHanSerifSCVF-ExtraLight",
                kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [2003265652: 700] // wght axis = Bold
            ])
            font = UIFont(descriptor: descriptor, size: 22)
        } else {
            font = UIFont(name: "Merriweather-Bold", size: 23) ?? UIFont.systemFont(ofSize: 23, weight: .bold)
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 12

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )

        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0

        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var lastLineRect: CGRect?

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            lastLineRect = usedRect
        }

        return lastLineRect
    }

    private var generationToastView: some View {
        let isSuccess = generationToastMessage.localizedCaseInsensitiveContains("new")
        let iconName = isSuccess ? "sparkles" : "hourglass"
        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
            Text(generationToastMessage)
                .font(.custom("Merriweather-Regular", size: 13))
        }
        .foregroundColor(themeManager.primaryText.opacity(0.95))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel(Text(generationToastMessage))
    }

    private func focusGuidanceRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.primaryText.opacity(0.82))
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Merriweather-Bold", size: 12))
                    .foregroundColor(themeManager.primaryText.opacity(0.9))

                Text(body)
                    .font(.custom("Merriweather-Regular", size: 12))
                    .foregroundColor(themeManager.descriptionText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func normalizedFocusText(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var seededMantraFocuses: [MantraFocus] {
        [
            MantraFocus(id: UUID(uuidString: dailyFocusID) ?? UUID(), name: "daily", description: "Your everyday grounding mantra.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: fertilityFocusID) ?? UUID(), name: "fertility", description: "Attention for conception, hormones, and family-building hopes.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: connectionFocusID) ?? UUID(), name: "connection", description: "A lens for intimacy, partnership, and emotional closeness.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: transitionFocusID) ?? UUID(), name: "transition", description: "Support for change, uncertainty, and a life in motion.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: caregivingFocusID) ?? UUID(), name: "caregiving", description: "Grounding while supporting someone who depends on you.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: recoveryFocusID) ?? UUID(), name: "recovery", description: "Space for repair, steadiness, and rebuilding your energy.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: clarityFocusID) ?? UUID(), name: "clarity", description: "Perspective for decisions, priorities, and what matters now.", createdAt: .distantPast),
            MantraFocus(id: UUID(uuidString: griefFocusID) ?? UUID(), name: "grief", description: "Holding space for loss, remembrance, and emotional tenderness.", createdAt: .distantPast)
        ]
    }

    private var seededFocusIDs: Set<String> {
        Set(seededMantraFocuses.map { $0.id.uuidString })
    }

    private var seededFocusesByID: [String: MantraFocus] {
        Dictionary(uniqueKeysWithValues: seededMantraFocuses.map { ($0.id.uuidString, $0) })
    }

    private var recommendedDefaultFocusIDs: [String] {
        var prioritized: [String] = []

        let isFemale = normalizedGender == "female"
        let isMale = normalizedGender == "male"
        let isSingle = normalizedRelationshipStatus == "single"
        let isPartnered = normalizedRelationshipStatus == "in a relationship"
        let isOtherRelationship = normalizedRelationshipStatus == "other"
        let age = userAge ?? 0

        if isFemale && isPartnered && (25...42).contains(age) {
            prioritized.append(fertilityFocusID)
        }

        if isPartnered {
            prioritized.append(connectionFocusID)
        }

        if age >= 45 {
            prioritized.append(caregivingFocusID)
            prioritized.append(recoveryFocusID)
        } else if age >= 32 {
            prioritized.append(recoveryFocusID)
        }

        if isSingle {
            prioritized.append(clarityFocusID)
            prioritized.append(transitionFocusID)
        }

        if isOtherRelationship {
            prioritized.append(transitionFocusID)
            prioritized.append(recoveryFocusID)
        }

        if isMale {
            prioritized.append(clarityFocusID)
        }

        prioritized.append(contentsOf: [
            recoveryFocusID,
            clarityFocusID,
            transitionFocusID,
            connectionFocusID,
            caregivingFocusID,
            griefFocusID,
            fertilityFocusID
        ])

        var uniqueIDs: [String] = [dailyFocusID]
        for id in prioritized where !uniqueIDs.contains(id) {
            uniqueIDs.append(id)
            if uniqueIDs.count == maxAppliedFocuses {
                break
            }
        }
        return uniqueIDs
    }

    private func syncSeededFocusDefinitions() {
        guard !mantraFocuses.isEmpty else { return }

        mantraFocuses = mantraFocuses.map { existing in
            guard let seeded = seededFocusesByID[existing.id.uuidString] else { return existing }
            return MantraFocus(
                id: existing.id,
                name: seeded.name,
                description: seeded.description,
                createdAt: existing.createdAt
            )
        }
    }

    private func loadMantraFocusesIfNeeded() {
        guard !hasLoadedMantraFocuses else { return }
        hasLoadedMantraFocuses = true

        if let data = mantraTagLibraryStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([MantraFocus].self, from: data) {
            mantraFocuses = decoded
        }

        if let data = mantraTagSelectionsStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            mantraFocusSelections = decoded
        }

        if let data = mantraFocusCacheStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [String: FocusedMantraEntry]].self, from: data) {
            mantraFocusCache = decoded
        }

        if let data = mantraActiveFocusStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            mantraActiveFocusByDay = decoded
        }

        if let data = mantraFocusUsageStorage.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: DailyFocusUsageEntry].self, from: data) {
            mantraFocusUsageByDay = decoded
        }

        if mantraFocuses.isEmpty {
            mantraFocuses = seededMantraFocuses
        } else {
            syncSeededFocusDefinitions()
            for seededFocus in seededMantraFocuses where !mantraFocuses.contains(where: { $0.name.caseInsensitiveCompare(seededFocus.name) == .orderedSame }) {
                mantraFocuses.append(seededFocus)
            }
        }

        ensureDefaultFocusSetupForToday()
        pruneInvalidFocusSelectionsAndPersist()
        // 每次启动都回到 daily focus，daily 是主 focus
        mantraActiveFocusByDay[currentFocusSelectionKey] = dailyFocusID
        persistMantraFocuses()
    }

    private func persistMantraFocuses() {
        // encoding 失败时保留原有存储，不清空
        if let data = try? JSONEncoder().encode(mantraFocuses),
           let string = String(data: data, encoding: .utf8) {
            mantraTagLibraryStorage = string
        }

        if let data = try? JSONEncoder().encode(mantraFocusSelections),
           let string = String(data: data, encoding: .utf8) {
            mantraTagSelectionsStorage = string
        }

        if let data = try? JSONEncoder().encode(mantraFocusCache),
           let string = String(data: data, encoding: .utf8) {
            mantraFocusCacheStorage = string
        }

        if let data = try? JSONEncoder().encode(mantraActiveFocusByDay),
           let string = String(data: data, encoding: .utf8) {
            mantraActiveFocusStorage = string
        }

        if let data = try? JSONEncoder().encode(mantraFocusUsageByDay),
           let string = String(data: data, encoding: .utf8) {
            mantraFocusUsageStorage = string
        }
    }

    private func ensureDefaultFocusSetupForToday() {
        let day = currentFocusSelectionKey
        let defaultIDs = recommendedDefaultFocusIDs
        let existing = mantraFocusSelections[day] ?? []
        if existing.isEmpty {
            mantraFocusSelections[day] = defaultIDs
        } else {
            var merged = existing.filter { mantraFocusLookup[$0] != nil }

            // legacy 迁移：只在第一次启动时执行一次，之后不再检查，避免误覆盖用户选择
            if !hasCompletedLegacyFocusMigration {
                let legacyDefaultSets = [
                    [dailyFocusID, fertilityFocusID, connectionFocusID],
                    [dailyFocusID, connectionFocusID, clarityFocusID],
                    [dailyFocusID, fertilityFocusID, clarityFocusID]
                ]
                let legacyFocusNames = Set(["dating", "money", "career", "friendship", "health", "vacation", "purpose"])
                let isLegacyNameSet = merged.count == maxAppliedFocuses && merged.allSatisfy { focusID in
                    guard let focus = mantraFocusLookup[focusID] else { return false }
                    return legacyFocusNames.contains(focus.name.lowercased())
                }
                if legacyDefaultSets.contains(merged) || isLegacyNameSet {
                    merged = defaultIDs
                }
                hasCompletedLegacyFocusMigration = true
            }

            if !merged.contains(dailyFocusID) {
                merged.insert(dailyFocusID, at: 0)
            }
            mantraFocusSelections[day] = Array(merged.prefix(maxAppliedFocuses))
        }

        if mantraActiveFocusByDay[day] == nil || mantraFocusLookup[mantraActiveFocusByDay[day] ?? ""] == nil {
            mantraActiveFocusByDay[day] = dailyFocusID
        }
    }

    private func pruneInvalidFocusSelectionsAndPersist() {
        let validIDs = Set(mantraFocuses.map { $0.id.uuidString })
        var pruned: [String: [String]] = [:]

        for (key, ids) in mantraFocusSelections {
            var normalized = ids.filter { validIDs.contains($0) }
            // daily 永远保留在首位；即使所有其他 focus 都失效，也用 daily 兜底
            if !normalized.contains(dailyFocusID), validIDs.contains(dailyFocusID) {
                normalized.insert(dailyFocusID, at: 0)
            }
            // 确保 daily 永远在首位
            if normalized.first != dailyFocusID, normalized.contains(dailyFocusID) {
                normalized.removeAll { $0 == dailyFocusID }
                normalized.insert(dailyFocusID, at: 0)
            }
            pruned[key] = Array(normalized.prefix(maxAppliedFocuses))
        }

        mantraFocusSelections = pruned
        // active focus 若失效则回退到 daily
        mantraActiveFocusByDay = mantraActiveFocusByDay.mapValues { value in
            validIDs.contains(value) ? value : dailyFocusID
        }.filter { key, _ in
            mantraFocusSelections[key] != nil
        }
    }

    private func updateAppliedMantraFocusIDs(_ ids: [String]) {
        let cleaned = Array(ids.prefix(maxAppliedFocuses))
        mantraFocusSelections[currentFocusSelectionKey] = cleaned
        if !cleaned.contains(activeFocusID) {
            mantraActiveFocusByDay[currentFocusSelectionKey] = cleaned.first ?? dailyFocusID
        }
        persistMantraFocuses()
    }

    private func updateActiveFocusID(_ focusID: String) {
        mantraActiveFocusByDay[currentFocusSelectionKey] = focusID
        persistMantraFocuses()
    }

    private func focusEntry(for focusID: String, day: String? = nil) -> FocusedMantraEntry? {
        mantraFocusCache[day ?? currentFocusSelectionKey]?[focusID]
    }

    private func cacheFocusedEntry(_ entry: FocusedMantraEntry, for focusID: String, day: String? = nil) {
        let key = day ?? currentFocusSelectionKey
        var entries = mantraFocusCache[key] ?? [:]
        entries[focusID] = entry
        mantraFocusCache[key] = entries
        persistMantraFocuses()
    }

    private func applyFocusedEntry(_ entry: FocusedMantraEntry, focusID: String) {
        let displayRecommendations: [String: String]
        let displayReasoningSummary: String
        let displayHowToEngage: [String: String]
        let displayLocationName: String

        if entry.isDefault {
            displayRecommendations = entry.recommendations
            displayReasoningSummary = entry.reasoningSummary
            displayHowToEngage = entry.howToEngage
            displayLocationName = entry.locationName
        } else if let dailyEntry = focusEntry(for: dailyFocusID) {
            displayRecommendations = dailyEntry.recommendations
            displayReasoningSummary = dailyEntry.reasoningSummary
            // howToEngage 始终使用 daily 的，切换 focus 不影响 8 大类的 how to engage
            displayHowToEngage = dailyEntry.howToEngage
            displayLocationName = dailyEntry.locationName
        } else {
            displayRecommendations = viewModel.recommendations
            displayReasoningSummary = viewModel.reasoningSummary
            // 没有 daily 缓存时也保持当前 viewModel 的 howToEngage（daily 来源）
            displayHowToEngage = viewModel.howToEngage
            displayLocationName = lastRecommendationPlace
        }

        updateActiveFocusID(focusID)
        viewModel.dailyMantra = entry.mantra
        viewModel.recommendations = displayRecommendations
        viewModel.reasoningSummary = displayReasoningSummary
        viewModel.howToEngage = displayHowToEngage
        lastRecommendationPlace = displayLocationName
        lastRecommendationDate = todayString()
        isDefaultRecommendation = entry.isDefault
        updateLastRecommendationStampIfReady(mantra: entry.mantra, recs: displayRecommendations, isDefault: entry.isDefault)
        fetchAllRecommendationTitles()
        persistWidgetSnapshotFromViewModel()
        markMantraReadyIfPossible()
    }

    private func cacheCurrentDailyFocusIfPossible(day: String? = nil) {
        let mantra = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mantra.isEmpty, !viewModel.recommendations.isEmpty else { return }

        let entry = FocusedMantraEntry(
            mantra: mantra,
            recommendations: viewModel.recommendations,
            reasoningSummary: viewModel.reasoningSummary,
            howToEngage: viewModel.howToEngage,
            locationName: lastRecommendationPlace,
            savedAt: Date(),
            isDefault: isDefaultRecommendation
        )
        cacheFocusedEntry(entry, for: dailyFocusID, day: day)
    }

    private func focusWordCount(for value: String) -> Int {
        let normalized = normalizedFocusText(value)
        guard !normalized.isEmpty else { return 0 }
        return normalized.split(separator: " ").count
    }

    private func isDuplicateFocusName(_ value: String) -> Bool {
        let normalized = normalizedFocusText(value).lowercased()
        return mantraFocuses.contains { $0.name.lowercased() == normalized }
    }

    private func setFocusManagerMessage(_ message: String, isError: Bool = false) {
        focusManagerMessage = message
        focusManagerMessageIsError = isError
    }

    private func clearFocusManagerMessage() {
        focusManagerMessage = ""
        focusManagerMessageIsError = false
    }

    private func showFocusAlert(title: String = "Focus Update", message: String) {
        presentMainViewDialog(
            title: title,
            message: message,
            symbol: title == "Focus Limit Reached" ? "clock.badge.exclamationmark" : "sparkles.square.filled.on.square"
        )
    }

    private func presentMainViewDialog(
        title: String,
        message: String,
        symbol: String,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        isLocationPermissionDialog: Bool = false,
        tone: AlynnaDialogTone = .info
    ) {
        mainViewDialogTitle = title
        mainViewDialogMessage = message
        mainViewDialogSymbol = symbol
        mainViewDialogPrimaryButtonTitle = primaryButtonTitle
        mainViewDialogPrimaryAction = primaryAction
        mainViewDialogIsLocationPermission = isLocationPermissionDialog
        mainViewDialogTone = tone
        withAnimation(.easeOut(duration: 0.2)) {
            showMainViewDialog = true
        }
    }

    private func dismissMainViewDialog() {
        mainViewDialogPrimaryButtonTitle = nil
        mainViewDialogPrimaryAction = nil
        mainViewDialogIsLocationPermission = false
        mainViewDialogTone = .info
        withAnimation(.easeOut(duration: 0.2)) {
            showMainViewDialog = false
        }
    }

    private func openAppSettings() {
        locationPermissionCoordinator.openAppSettings()
    }

    private func presentLocationPermissionRequiredAlert(for focusName: String? = nil) {
        let message: String
        if let focusName {
            message = "Turn on Location Access in Settings. Alynna uses weather, humidity, pressure, and nearby conditions to shape your \(focusName) mantra."
        } else {
            message = "Turn on Location Access in Settings. Alynna uses weather, humidity, pressure, and nearby conditions to calculate your mantra and rhythm."
        }
        presentMainViewDialog(
            title: "Location Access Matters",
            message: message,
            symbol: "location.slash.circle",
            primaryButtonTitle: "Open Settings",
            primaryAction: openAppSettings,
            isLocationPermissionDialog: true,
            tone: .warning
        )
    }

    private func canProceedWithLocationRefresh() -> Bool {
        let authorizationStatus = locationPermissionCoordinator.authorizationStatus
        switch authorizationStatus {
        case .denied, .restricted:
            presentLocationPermissionRequiredAlert()
            return false
        default:
            return true
        }
    }

    private func nonDailyFocusLimitMessage() -> String {
        "For now, non-daily focuses can be refreshed up to 2 times per day, and each selected focus can only be updated once per day. If you want to explore more, please choose carefully and come back tomorrow. We’re also working on a subscription plan with more access. Thank you for your patience."
    }

    private func nonDailyUsageCount(for day: String? = nil) -> Int {
        if isPrivilegedUser { return 0 }
        let key = day ?? currentFocusSelectionKey
        return mantraFocusUsageByDay[key]?.generatedFocuses.keys.count ?? 0
    }

    private func hasGeneratedNonDailyFocusToday(_ focusID: String, day: String? = nil) -> Bool {
        if isPrivilegedUser { return false }
        let key = day ?? currentFocusSelectionKey
        return (mantraFocusUsageByDay[key]?.generatedFocuses[focusID] ?? 0) > 0
    }

    private func recordNonDailyFocusGeneration(_ focusID: String, day: String? = nil) {
        let key = day ?? currentFocusSelectionKey
        var usage = mantraFocusUsageByDay[key] ?? DailyFocusUsageEntry(generatedFocuses: [:])
        usage.generatedFocuses[focusID] = 1
        mantraFocusUsageByDay[key] = usage
        persistMantraFocuses()
    }

    private func submitNewFocus() {
        createFocus(nameInput: newFocusName, descriptionInput: newFocusDescription)
    }

    private func saveFocusFromButtonTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            submitNewFocus()
        }
    }

    private func selectFocus(_ focus: MantraFocus) {
        loadMantraFocusesIfNeeded()

        let focusID = focus.id.uuidString
        if activeFocusID == focusID {
            return
        }

        if focusID != dailyFocusID {
            dismissFocusHelperIfNeeded()
        }

        if activeFocusID == dailyFocusID {
            cacheCurrentDailyFocusIfPossible()
        }

        if let entry = focusEntry(for: focusID) {
            applyFocusedEntry(entry, focusID: focusID)
            return
        }

        if focusID != dailyFocusID {
            if hasGeneratedNonDailyFocusToday(focusID) {
                showFocusAlert(title: "Focus Limit Reached", message: nonDailyFocusLimitMessage())
                return
            }

            if nonDailyUsageCount() >= maxNonDailyFocusUpdatesPerDay {
                showFocusAlert(title: "Focus Limit Reached", message: nonDailyFocusLimitMessage())
                return
            }
        }

        previousActiveFocusIDBeforeFocusRequest = activeFocusID
        updateActiveFocusID(focusID)

        if focusID == dailyFocusID {
            loadTodayRecommendation(day: todayString(), source: .default, allowRemoteFallback: true)
        } else {
            generateFocusedMantra(for: focus)
        }
    }

    private func toggleFocusVisibility(_ focus: MantraFocus) {
        loadMantraFocusesIfNeeded()

        let focusID = focus.id.uuidString
        var ids = appliedMantraFocusIDs

        if let index = ids.firstIndex(of: focusID) {
            if focusID == dailyFocusID {
                setFocusManagerMessage("Daily stays pinned so you can always return to the daily mantra.", isError: true)
                return
            }
            dismissFocusHelperIfNeeded()
            let wasActive = activeFocusID == focusID
            ids.remove(at: index)
            updateAppliedMantraFocusIDs(ids)
            clearFocusManagerMessage()
            if wasActive {
                let fallbackFocusID = ids.first ?? dailyFocusID
                if let entry = focusEntry(for: fallbackFocusID) {
                    applyFocusedEntry(entry, focusID: fallbackFocusID)
                } else {
                    updateActiveFocusID(fallbackFocusID)
                    loadTodayRecommendation(day: todayString(), source: .default, allowRemoteFallback: true)
                }
            }
            return
        }

        guard ids.count < maxAppliedFocuses else {
            setFocusManagerMessage("Show up to 3 focuses under the mantra. Remove one first to add another.", isError: true)
            return
        }

        ids.append(focusID)
        dismissFocusHelperIfNeeded()
        updateAppliedMantraFocusIDs(ids)
        clearFocusManagerMessage()
        selectFocus(focus)
    }

    private func createFocus(nameInput: String? = nil, descriptionInput: String? = nil) {
        loadMantraFocusesIfNeeded()

        let name = normalizedFocusText(nameInput ?? newFocusName)
        let description = normalizedFocusText(descriptionInput ?? newFocusDescription)

        guard !name.isEmpty else { return }

        guard focusWordCount(for: name) <= 2 else {
            setFocusManagerMessage("Each focus name can use up to 2 words.", isError: true)
            return
        }

        guard !description.isEmpty else {
            setFocusManagerMessage("Add a short description for this focus.", isError: true)
            return
        }

        guard !isDuplicateFocusName(name) else {
            setFocusManagerMessage("That focus already exists.", isError: true)
            return
        }

        let newFocus = MantraFocus(id: UUID(), name: name, description: description, createdAt: Date())
        mantraFocuses.insert(newFocus, at: 0)
        dismissFocusHelperIfNeeded()
        focusedFocusFormField = nil
        newFocusName = ""
        newFocusDescription = ""
        showNewFocusForm = false

        if canApplyMoreFocuses {
            var ids = appliedMantraFocusIDs
            ids.append(newFocus.id.uuidString)
            updateAppliedMantraFocusIDs(ids)
            selectFocus(newFocus)
            setFocusManagerMessage("Focus saved and added below the mantra.")
        } else {
            setFocusManagerMessage("Focus saved. Remove one current focus if you want to show it under the mantra.")
        }

        persistMantraFocuses()
    }

    private func deleteFocus(_ focus: MantraFocus) {
        guard focus.id.uuidString != dailyFocusID else {
            setFocusManagerMessage("Daily stays pinned and cannot be deleted.", isError: true)
            pendingFocusDeletion = nil
            return
        }

        let focusID = focus.id.uuidString
        mantraFocuses.removeAll { $0.id == focus.id }
        mantraFocusSelections = mantraFocusSelections.reduce(into: [:]) { partialResult, item in
            let filtered = item.value.filter { $0 != focusID }
            if !filtered.isEmpty {
                partialResult[item.key] = filtered
            }
        }
        mantraFocusCache = mantraFocusCache.reduce(into: [:]) { partialResult, item in
            var entries = item.value
            entries.removeValue(forKey: focusID)
            if !entries.isEmpty {
                partialResult[item.key] = entries
            }
        }
        if activeFocusID == focusID {
            if let dailyEntry = focusEntry(for: dailyFocusID) {
                applyFocusedEntry(dailyEntry, focusID: dailyFocusID)
            } else {
                updateActiveFocusID(dailyFocusID)
                loadTodayRecommendation(day: todayString(), source: .default, allowRemoteFallback: true)
            }
        }
        pendingFocusDeletion = nil
        setFocusManagerMessage("Focus deleted.")
        persistMantraFocuses()
    }

    private func resetNewFocusForm() {
        newFocusName = ""
        newFocusDescription = ""
        showNewFocusForm = false
    }

    private func restorePreviousFocusAfterFailure() {
        let fallbackFocusID = previousActiveFocusIDBeforeFocusRequest ?? dailyFocusID
        previousActiveFocusIDBeforeFocusRequest = nil
        focusGenerationTagID = nil

        if let entry = focusEntry(for: fallbackFocusID) {
            applyFocusedEntry(entry, focusID: fallbackFocusID)
        } else {
            updateActiveFocusID(dailyFocusID)
            loadTodayRecommendation(day: todayString(), source: .default, allowRemoteFallback: true)
        }
    }

    private func generateFocusedMantra(for focus: MantraFocus) {
        guard focusGenerationTagID == nil || focusGenerationTagID == focus.id.uuidString else {
            showFocusAlert(message: "A focus mantra is already generating. Please wait a moment.")
            return
        }

        focusGenerationTagID = focus.id.uuidString
        showMainGenerationOverlay = true
        configureFocusGenerationOverlay(for: focus.name)
        beginGenerationFlow()

        func request(using coord: CLLocationCoordinate2D) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let birthDateString = dateFormatter.string(from: viewModel.birth_date)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

            var payload: [String: Any] = [
                "birth_date": birthDateString,
                "birth_time": birthTimeString,
                "latitude": coord.latitude,
                "longitude": coord.longitude,
                "focus_tag": focus.name,
                "focus_description": focus.description,
                "focus_mode": "personal"
            ]
            attachRecommendationLanguage(to: &payload)

            if !viewModel.currentPlace.isEmpty                        { payload["current_place"]      = viewModel.currentPlace }
            if let v = viewModel.weatherCondition                     { payload["weather_condition"]   = v }
            if let v = viewModel.temperature                          { payload["temperature"]         = v }
            if let v = viewModel.windDirection                        { payload["wind_direction"]      = v }
            if let v = viewModel.windSpeed                            { payload["wind_speed"]          = v }
            if let v = viewModel.humidity                             { payload["humidity"]            = v }
            if let v = viewModel.pressure                             { payload["pressure"]            = v }
            if let v = viewModel.airQualityAQI                        { payload["air_quality_aqi"]     = v }
            if let v = viewModel.airQualityPM25                       { payload["air_quality_pm2_5"]   = v }
            if let v = viewModel.waterPercent                         { payload["water_percent"]       = v }
            if let v = viewModel.greenPercent                         { payload["green_percent"]       = v }
            if let v = viewModel.builtPercent                         { payload["built_percent"]       = v }
            if let v = viewModel.checkInMood                          { payload["mood"]                = v }
            if let v = viewModel.checkInStress                        { payload["stress"]              = v }
            if let v = viewModel.checkInSleep                         { payload["sleep"]               = v }

            let trimmedNotes = viewModel.checkInNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty                                  { payload["personal_notes"]      = trimmedNotes }

            guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
                showFocusAlert(message: "Unable to start the focus mantra request right now.")
                completeGenerationIfNeeded(isDefault: true)
                restorePreviousFocusAfterFailure()
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                showFocusAlert(message: "Unable to prepare this focus mantra request.")
                completeGenerationIfNeeded(isDefault: true)
                restorePreviousFocusAfterFailure()
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.showFocusAlert(message: "Could not generate the \(focus.name) mantra: \(error.localizedDescription)")
                        self.completeGenerationIfNeeded(isDefault: true)
                        self.restorePreviousFocusAfterFailure()
                    }
                    return
                }

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                    DispatchQueue.main.async {
                        self.showFocusAlert(message: "The \(focus.name) mantra request did not finish successfully.")
                        self.completeGenerationIfNeeded(isDefault: true)
                        self.restorePreviousFocusAfterFailure()
                    }
                    return
                }

                do {
                    guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let mantra = parsed["mantra"] as? String else {
                        DispatchQueue.main.async {
                            self.showFocusAlert(message: "The \(focus.name) mantra response was incomplete.")
                            self.completeGenerationIfNeeded(isDefault: true)
                            self.restorePreviousFocusAfterFailure()
                        }
                        return
                    }

                    let reasoningSummary: String = {
                        if let s = parsed["reasoning_summary"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
                        if let explanation = parsed["explanation"] as? [String: Any],
                           let s = explanation["reasoning_summary"] as? String,
                           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return s
                        }
                        return ""
                    }()

                    func coerceStringDict(_ any: Any?) -> [String: String] {
                        if let dict = any as? [String: String] { return dict }
                        guard let dict = any as? [String: Any] else { return [:] }
                        return dict.reduce(into: [String: String]()) { acc, pair in
                            if let s = pair.value as? String { acc[pair.key] = s }
                        }
                    }

                    let normalizedHowToEngage: [String: String] = {
                        let raw: [String: String]
                        if let explanation = parsed["explanation"] as? [String: Any],
                           let engageAny = explanation["how_to_engage"] {
                            raw = coerceStringDict(engageAny)
                        } else if let engageAny = parsed["how_to_engage"] {
                            raw = coerceStringDict(engageAny)
                        } else {
                            raw = [:]
                        }

                        return raw.reduce(into: [:]) { acc, pair in
                            let key = self.canonicalCategory(from: pair.key) ?? pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty else { return }
                            acc[key] = pair.value
                        }
                    }()

                    let normalized: [String: String] = {
                        if let recs = parsed["recommendations"] as? [String: String] {
                            let reduced = recs.reduce(into: [String: String]()) { acc, kv in
                                if let canon = canonicalCategory(from: kv.key) {
                                    acc[canon] = sanitizeDocumentName(kv.value)
                                }
                            }
                            if !reduced.isEmpty {
                                return reduced
                            }
                        }

                        if let dailyEntry = self.focusEntry(for: self.dailyFocusID) {
                            return dailyEntry.recommendations
                        }

                        return self.viewModel.recommendations
                    }()

                    let resolvedPlace = self.lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? self.viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                        : self.lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines)

                    let entry = FocusedMantraEntry(
                        mantra: mantra,
                        recommendations: normalized,
                        reasoningSummary: reasoningSummary,
                        howToEngage: normalizedHowToEngage,
                        locationName: resolvedPlace,
                        savedAt: Date(),
                        isDefault: false
                    )

                    DispatchQueue.main.async {
                        self.recordNonDailyFocusGeneration(focus.id.uuidString)
                        self.cacheFocusedEntry(entry, for: focus.id.uuidString)
                        self.applyFocusedEntry(entry, focusID: focus.id.uuidString)
                        self.focusGenerationTagID = nil
                        self.previousActiveFocusIDBeforeFocusRequest = nil
                        self.completeGenerationIfNeeded(isDefault: false)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showFocusAlert(message: "Could not read the \(focus.name) mantra response.")
                        self.completeGenerationIfNeeded(isDefault: true)
                        self.restorePreviousFocusAfterFailure()
                    }
                }
            }.resume()
        }

        let authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .denied, .restricted:
            presentLocationPermissionRequiredAlert(for: focus.name)
            completeGenerationIfNeeded(isDefault: true)
            restorePreviousFocusAfterFailure()
            return
        case .notDetermined, .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            presentLocationPermissionRequiredAlert(for: focus.name)
            completeGenerationIfNeeded(isDefault: true)
            restorePreviousFocusAfterFailure()
            return
        }

        if let coord = locationManager.currentLocation {
            request(using: coord)
            return
        }

        locationManager.requestLocation()
        let start = Date()
        let timeout: TimeInterval = 8.0

        func poll() {
            if let coord = locationManager.currentLocation {
                request(using: coord)
                return
            }
            let latestAuthorizationStatus = locationManager.authorizationStatus
            if latestAuthorizationStatus == .denied || latestAuthorizationStatus == .restricted {
                presentLocationPermissionRequiredAlert(for: focus.name)
                completeGenerationIfNeeded(isDefault: true)
                restorePreviousFocusAfterFailure()
                return
            }
            if Date().timeIntervalSince(start) > timeout {
                showFocusAlert(message: "Location is taking too long. Try the \(focus.name) mantra again in a moment.")
                completeGenerationIfNeeded(isDefault: true)
                restorePreviousFocusAfterFailure()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: poll)
        }

        poll()
    }

    private var expandedMantraFocusStrip: some View {
        HStack(spacing: 8) {
            ForEach(appliedMantraFocuses.prefix(maxAppliedFocuses)) { focus in
                let isActive = activeFocusID == focus.id.uuidString
                Button {
                    selectFocus(focus)
                } label: {
                    Text(focus.name)
                        .font(.custom("Merriweather-Regular", size: 12))
                        .foregroundColor(isActive ? Color.black.opacity(0.78) : themeManager.primaryText.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(
                                    isActive
                                        ? Color(red: 0.94, green: 0.88, blue: 0.72).opacity(themeManager.isNight ? 0.92 : 0.84)
                                        : themeManager.panelFill.opacity(themeManager.isNight ? 0.38 : 0.48)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isActive ? Color.white.opacity(0.32) : Color.white.opacity(0.16),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                loadMantraFocusesIfNeeded()
                showFocusHint = true
                showFocusManagerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("focus")
                        .font(.custom("Merriweather-Regular", size: 12))
                }
                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(themeManager.panelFill.opacity(themeManager.isNight ? 0.24 : 0.3))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }

    private var focusManagerSheet: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("main.focus_how_it_works")
                            .font(.custom("Merriweather-Bold", size: 13))
                            .foregroundColor(themeManager.primaryText.opacity(0.92))
                            .padding(.bottom, 2)

                        Text("main.focus_explanation")
                            .font(.custom("Merriweather-Regular", size: 12))
                            .foregroundColor(themeManager.descriptionText.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)

                        focusGuidanceRow(
                            symbol: "heart.text.square",
                            title: "Health note",
                            body: "If a focus relates to your physical or mental health, treat Alynna as supportive guidance only and continue to follow professional medical advice."
                        )
                    }
                    .padding(.vertical, 4)
                }

                Section("Current Focus") {
                    if let activeFocus {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeFocus.name)
                                .font(.custom("Merriweather-Bold", size: 14))
                                .foregroundColor(themeManager.primaryText)
                            Text(activeFocus.description)
                                .font(.custom("Merriweather-Regular", size: 12))
                                .foregroundColor(themeManager.descriptionText.opacity(0.74))
                        }
                    }
                }

                Section("Preset Focuses") {
                    ForEach(seededMantraFocuses) { focus in
                        let isVisible = appliedMantraFocusIDs.contains(focus.id.uuidString)
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                if isVisible {
                                    selectFocus(focus)
                                } else {
                                    toggleFocusVisibility(focus)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(focus.name)
                                        .font(.custom("Merriweather-Bold", size: 14))
                                        .foregroundColor(themeManager.primaryText)
                                    Text(focus.description)
                                        .font(.custom("Merriweather-Regular", size: 12))
                                        .foregroundColor(themeManager.descriptionText.opacity(0.74))
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(!isVisible && !canApplyMoreFocuses ? 0.45 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isVisible && !canApplyMoreFocuses)

                            Button {
                                if isVisible, focus.id.uuidString != dailyFocusID {
                                    toggleFocusVisibility(focus)
                                } else if !isVisible {
                                    toggleFocusVisibility(focus)
                                }
                            } label: {
                                Image(systemName: isVisible ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(
                                        isVisible
                                            ? themeManager.primaryText.opacity(0.86)
                                            : themeManager.descriptionText.opacity(0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(focus.id.uuidString == dailyFocusID || (!isVisible && !canApplyMoreFocuses))

                            if focus.id.uuidString != dailyFocusID {
                                Button(role: .destructive) {
                                    pendingFocusDeletion = focus
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Custom Focuses") {
                    let customFocuses = mantraFocuses.filter { !seededFocusIDs.contains($0.id.uuidString) }
                    if !focusManagerMessage.isEmpty {
                        Text(focusManagerMessage)
                            .font(.custom("Merriweather-Regular", size: 12))
                            .foregroundColor(
                                focusManagerMessageIsError
                                    ? Color.red.opacity(0.88)
                                    : themeManager.descriptionText.opacity(0.82)
                            )
                            .multilineTextAlignment(.leading)
                    }
                    if customFocuses.isEmpty {
                        Text("main.no_custom_focuses")
                            .font(.custom("Merriweather-Regular", size: 14))
                            .foregroundColor(themeManager.descriptionText.opacity(0.72))
                    } else {
                        ForEach(customFocuses) { focus in
                            let isVisible = appliedMantraFocusIDs.contains(focus.id.uuidString)
                            HStack(alignment: .top, spacing: 12) {
                                Button {
                                    if isVisible {
                                        selectFocus(focus)
                                    } else {
                                        toggleFocusVisibility(focus)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(focus.name)
                                            .font(.custom("Merriweather-Bold", size: 14))
                                            .foregroundColor(themeManager.primaryText)
                                        Text(focus.description)
                                            .font(.custom("Merriweather-Regular", size: 12))
                                            .foregroundColor(themeManager.descriptionText.opacity(0.74))
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .opacity(!isVisible && !canApplyMoreFocuses ? 0.45 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(!isVisible && !canApplyMoreFocuses)

                                Button {
                                    toggleFocusVisibility(focus)
                                } label: {
                                    Image(systemName: isVisible ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(
                                            isVisible
                                                ? themeManager.primaryText.opacity(0.86)
                                                : themeManager.descriptionText.opacity(0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(!isVisible && !canApplyMoreFocuses)

                                Button(role: .destructive) {
                                    pendingFocusDeletion = focus
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    if showNewFocusForm {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("main.be_precise")
                                    .font(.custom("Merriweather-Bold", size: 12))
                                    .foregroundColor(themeManager.primaryText.opacity(0.9))

                                Text("main.focus_precision_hint")
                                    .font(.custom("Merriweather-Regular", size: 12))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            TextField("Focus name", text: $newFocusName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($focusedFocusFormField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedFocusFormField = .description
                                }

                            Text("main.focus_name_hint")
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.descriptionText.opacity(0.7))

                            TextField("What should this focus hold space for?", text: $newFocusDescription, axis: .vertical)
                                .lineLimit(3...5)
                                .textInputAutocapitalization(.sentences)
                                .focused($focusedFocusFormField, equals: .description)
                                .submitLabel(.done)
                                .onSubmit {
                                    submitNewFocus()
                                }

                            HStack {
                                Button("Cancel") {
                                    resetNewFocusForm()
                                }
                                .foregroundColor(themeManager.descriptionText.opacity(0.85))

                                Spacer()

                                Button {
                                    saveFocusFromButtonTap()
                                } label: {
                                    Text("main.save_focus")
                                        .frame(minWidth: 96, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .font(.custom("Merriweather-Regular", size: 14))
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            clearFocusManagerMessage()
                            showNewFocusForm = true
                        } label: {
                            Label("New Custom Focus", systemImage: "plus")
                                .font(.custom("Merriweather-Regular", size: 14))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.panelFill.opacity(themeManager.isNight ? 0.95 : 0.9))
            .navigationTitle("Focuses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showFocusManagerSheet = false
                    }
                    .foregroundColor(themeManager.primaryText)
                }
            }
            .confirmationDialog(
                "Delete Focus?",
                isPresented: Binding(
                    get: { pendingFocusDeletion != nil },
                    set: { if !$0 { pendingFocusDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let focus = pendingFocusDeletion {
                    Button("Delete \"\(focus.name)\" Focus", role: .destructive) {
                        deleteFocus(focus)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingFocusDeletion = nil
                }
            } message: {
                if let focus = pendingFocusDeletion {
                    Text("This deletes \(focus.name) everywhere it appears and clears its cached focused mantra.")
                }
            }
        }
    }

    private func showNoSoundToastIfNeeded() {
        guard !showNoSoundToast else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showNoSoundToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.2)) {
                showNoSoundToast = false
            }
        }
    }

    private func scheduleSoundPlayerAutoDismiss() {
        isAutoDismissSoundPlayer = true
        soundPlayerAutoDismissTask?.cancel()
        soundPlayerAutoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard showTodaySoundPlayer, isAutoDismissSoundPlayer else { return }
            showTodaySoundPlayer = false
        }
    }

    
    private var mainContent: some View {
        NavigationStack(path: $mainNavigationPath) {
            ZStack {
                // ✅ Full-screen background, not constrained by inner GeometryReader
                AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // ✅ Foreground content uses GeometryReader for layout
                GeometryReader { geometry in
                    let minLength = min(geometry.size.width, geometry.size.height)

                    VStack(spacing: minLength * 0.015) {
                        // 顶部按钮
                        HStack {
                            
                            HStack(spacing: geometry.size.width * 0.035) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        journalSpinAngle += 360
                                    }
                                    handleManualRefreshTap()
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.primaryText)
                                        .frame(width: 28, height: 28)
                                        .rotationEffect(.degrees(journalSpinAngle))
                                }
                                .disabled(isFetchingToday || isManualRefreshFlow)
                                .accessibilityLabel("Refresh")
                            }
                            .padding(.leading, geometry.size.width * 0.05)

                            Spacer()

                            HStack(spacing: geometry.size.width * 0.02) {

                                if isLoggedIn {
                                    NavigationLink(
                                        destination: ProfileView(viewModel: viewModel)
                                            .environmentObject(starManager)
                                            .environmentObject(themeManager)
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.primaryText)
                                    }
                                } else {
                                    NavigationLink(
                                        destination: ProfileView(viewModel: viewModel)
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.primaryText)
                                    }
                                }
                            }
                            .padding(.trailing, geometry.size.width * 0.05)

                        }

                        VStack(spacing: 4) {
                            Text("main.todays_rhythm")
                                .font(.custom("Merriweather-SemiBold", size: 34))
                                .lineSpacing(AlignaType.logoLineSpacing)
                                .foregroundColor(themeManager.primaryText)

                            Text(rhythmHeaderSubtitle)
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.52))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .overlay(alignment: .topTrailing) {
                            if shouldShowCompactFocusBadge, let activeFocus {
                                Text(activeFocus.name)
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.primaryText.opacity(0.84))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(themeManager.panelFill.opacity(themeManager.isNight ? 0.42 : 0.55))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                    )
                                    .offset(x: 18, y: -13)
                            }
                        }
                        .padding(.top, 20)
                        .opacity(isMantraExpanded ? 0 : 1)
                        .scaleEffect(isMantraExpanded ? 0.92 : 1)
                        .frame(height: isMantraExpanded ? 0 : nil)
                        .allowsHitTesting(false)




                        Group {
                            if isMantraExpanded {
                                let textWidth = geometry.size.width * 0.72
                                let topInset = geometry.size.height * 0.16
                                let lastLineRect = expandedMantraLastLineRect(for: viewModel.dailyMantra, width: textWidth)

                                VStack(spacing: 0) {
                                    ZStack(alignment: .topLeading) {
                                        VStack(spacing: 1) {
                                            Text(viewModel.dailyMantra)
                                                .font(AlignaType.expandedMantraFont())
                                                .lineSpacing(12)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(
                                                    themeManager.primaryText.opacity(themeManager.isNight ? 0.94 : 0.88)
                                                )
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(width: textWidth)

                                            if shouldShowMantraGuidanceHint {
                                                Text("main.mantra_expand_hint")
                                                    .font(.custom("Merriweather-Regular", size: 11))
                                                    .foregroundColor(themeManager.descriptionText.opacity(0.68))
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: textWidth * 0.96)
                                                    .transition(.opacity)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            toggleMantraExpansion()
                                        }

                                        if let lastLineRect {
                                            // 紧跟句尾，垂直居中于最后一行
                                            // x: 句尾右端 + 小间距（icon 自带 padding=8，.position 按中心定位，无需额外补偿）
                                            expandedMantraInfoBadge
                                                .position(
                                                    x: min(lastLineRect.maxX + 16, textWidth - 2),
                                                    y: lastLineRect.midY
                                                )
                                        }
                                    }
                                    .frame(width: textWidth, alignment: .center)
                                    .padding(.top, topInset)
                                    .padding(.bottom, shouldShowMantraGuidanceHint ? 8 : 18)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleMantraExpansion()
                                }
                            } else {
                                Button {
                                    toggleMantraExpansion()
                                } label: {
                                    Text(viewModel.dailyMantra)
                                        .font(AlignaType.homeMantraFont())
                                        .lineSpacing(AlignaType.descLineSpacing)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(themeManager.descriptionText.opacity(0.72))
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .padding(.horizontal, geometry.size.width * 0.1)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: isMantraExpanded ? .infinity : nil, alignment: isMantraExpanded ? .top : .center)
                        .opacity(isMantraReady ? 1 : 0)
                        .allowsHitTesting(isMantraReady)
                        
                        if isMantraExpanded {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    if focusHelperShowsProgress {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(themeManager.descriptionText.opacity(0.75))
                                            .scaleEffect(0.8)
                                    }

                                    if shouldShowFocusHelper {
                                        Text(focusHelperText)
                                            .font(AlignaType.helperSmall())
                                            .lineSpacing(AlignaType.small14LineSpacing)
                                            .foregroundColor(themeManager.descriptionText.opacity(0.75))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.horizontal, geometry.size.width * 0.12)

                                expandedMantraFocusStrip
                            }
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))

                            let actionButtonSize: CGFloat = 32
                            HStack(spacing: 12) {
                                Button {
                                    showWallpaperPreview = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(AlynnaTypography.font(.footnote))
                                        .foregroundColor(themeManager.primaryText)
                                        .frame(width: actionButtonSize, height: actionButtonSize)
                                        .contentShape(Rectangle())
                                }
                                .sheet(isPresented: $showWallpaperPreview) {
                                    WallpaperPreviewView(
                                        mantra: viewModel.dailyMantra,
                                        colorHex: todayColorHex() ?? "#CBBBA0"
                                    )
                                }

                                Button {
                                    if isTodaySoundPlaying {
                                        soundPlayer.pause()
                                    } else if todaySoundKey.isEmpty {
                                        showNoSoundToastIfNeeded()
                                    } else {
                                        soundPlayer.playSound(named: todaySoundKey)
                                        showTodaySoundPlayer = true
                                        scheduleSoundPlayerAutoDismiss()
                                    }
                                } label: {
                                    Group {
                                        if isTodaySoundLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(themeManager.primaryText)
                                        } else if isTodaySoundPlaying {
                                            Image(systemName: "pause.fill")
                                                .font(AlynnaTypography.font(.footnote))
                                                .foregroundColor(themeManager.primaryText)
                                                .breathingIcon(scale: 1.06, minOpacity: 0.8, duration: 1.6)
                                        } else {
                                            Image(systemName: "play.fill")
                                                .font(AlynnaTypography.font(.footnote))
                                                .foregroundColor(
                                                    themeManager.primaryText.opacity(todaySoundKey.isEmpty ? 0.35 : 1)
                                                )
                                        }
                                    }
                                    .frame(width: actionButtonSize, height: actionButtonSize)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showTodaySoundPlayer, onDismiss: {
                                    isAutoDismissSoundPlayer = false
                                    soundPlayerAutoDismissTask?.cancel()
                                    soundPlayerAutoDismissTask = nil
                                }) {
                                    PlayerPopup(
                                        documentName: todaySoundKey,
                                        dismiss: { showTodaySoundPlayer = false }
                                    )
                                    .presentationBackground(.clear)
                                    .presentationDetents([.fraction(0.6), .large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCornerRadius(24)
                                }

                            }
                            .padding(.top, 8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: isMantraExpanded)
                        }
                        // ✅ 当 mantra 更新（新的一天/重新拉取）时，自动收起回 “...”
                        

                    }
                    .padding(.top, 16)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .top)
                    .preferredColorScheme(themeManager.preferredColorScheme)
                    .onAppear {
                        starManager.animateStar = true
                        themeManager.appBecameActive()
                        loadMantraFocusesIfNeeded()
                        ensureDefaultsIfMissing()
                        fetchAllRecommendationTitles()
                        if !todaySoundKey.isEmpty, todaySoundKey != lastPrefetchedSoundKey {
                            lastPrefetchedSoundKey = todaySoundKey
                            soundPlayer.prefetch(named: todaySoundKey)
                        }
                    }
                    .onChange(of: viewModel.dailyMantra) {
                        if bootPhase == .main {
                            markMantraReadyIfPossible()
                        }
                    }
                    .coordinateSpace(name: "HomeSpace")
                    .overlay(alignment: .topLeading) { }
                    .overlay(alignment: .top) {
                        if !isMantraExpanded {
                            let totalH = geometry.size.height
                            let gridSpacing = minLength * 0.018
                            // geometry.size.height 已扣除 safeAreaInset footer，无需额外 clearance
                            // grid 从屏幕 40% 处开始（mantra 约在 38% 处结束，留 2% 间距）
                            let gridTopOffset = totalH * 0.28
                            // 底部保留 12pt 视觉间距，其余全部给 grid
                            let gridAvailableH = totalH - gridTopOffset - 12
                            // 4 行卡片，3 个行间距
                            let cellHeight = max(56, (gridAvailableH - gridSpacing * 3) / 4)

                            let columns = [
                                GridItem(.flexible(), spacing: gridSpacing, alignment: .center),
                                GridItem(.flexible(), spacing: gridSpacing, alignment: .center)
                            ]
                            let gridItems = [
                                "Place", "Gemstone", "Color", "Scent",
                                "Activity", "Sound", "Career", "Relationship"
                            ]

                            LazyVGrid(columns: columns, spacing: gridSpacing) {
                                ForEach(Array(gridItems.enumerated()), id: \.offset) { index, title in
                                    navItemView(title: title, geometry: geometry,
                                                index: index, cellHeight: cellHeight)
                                }
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)
                            .padding(.top, gridTopOffset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.55), value: isMantraExpanded)
                        }
                    }
                }
            }
            // ✅ 只作用在首页这个 ZStack 上，push 新页面后不会带过去
            .safeAreaInset(edge: .bottom) {
                if !isMantraExpanded {
                    (
                        Text("main.attribution")
                    )
                    .font(.custom("Merriweather-Regular", size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if showNoSoundToast {
                    noSoundToastView
                        .padding(.bottom, isMantraExpanded ? 22 : 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                if showMainViewDialog {
                    mainViewDialog
                }
            }
            .sheet(isPresented: $showReasoningSheet) {
                ReasoningSummarySheet(text: viewModel.reasoningSummary)
                    .presentationDetents([.fraction(0.4), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showFocusManagerSheet, onDismiss: {
                resetNewFocusForm()
                clearFocusManagerMessage()
                pendingFocusDeletion = nil
            }) {
                focusManagerSheet
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .navigationDestination(for: RecCategory.self) { cat in
                RecommendationPagerView(
                    docsByCategory: makeDocsMap(),
                    selected: cat,
                    onBack: {
                        shouldCollapseMantraOnReturn = true
                        mainNavigationPath = NavigationPath()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMantraExpanded = false
                        }
                    }
                )
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
            }
        }
        .navigationViewStyle(.stack)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }


    private func persistWidgetSnapshotFromViewModel() {
        let mantra = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mantra.isEmpty else { return }

        func title(for key: String) -> String {
            let value = recommendationTitles[key] ?? viewModel.recommendations[key] ?? key
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? key : trimmed
        }

        let categoryReasoning: [String: String] = [
            "Place": reasoningStore.text(for: "Place"),
            "Gemstone": reasoningStore.text(for: "Gemstone"),
            "Color": reasoningStore.text(for: "Color"),
            "Scent": reasoningStore.text(for: "Scent"),
            "Activity": reasoningStore.text(for: "Activity"),
            "Sound": reasoningStore.text(for: "Sound"),
            "Career": reasoningStore.text(for: "Career"),
            "Relationship": reasoningStore.text(for: "Relationship")
        ]
        let reasoningSummary = viewModel.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        let snap = AlynnaWidgetSnapshot(
            mantra: mantra,
            locationName: resolvedWidgetLocation(),
            sunSign: widgetSunSign.trimmingCharacters(in: .whitespacesAndNewlines),
            moonSign: widgetMoonSign.trimmingCharacters(in: .whitespacesAndNewlines),
            risingSign: widgetRisingSign.trimmingCharacters(in: .whitespacesAndNewlines),
            weatherSummary: widgetWeatherSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            weatherDetailSummary: widgetWeatherDetailSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            environmentSummary: widgetEnvironmentSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            soundKey: soundKey(for: "Sound"),
            soundTitle: title(for: "Sound"),
            colorKey: soundKey(for: "Color"),
            colorTitle: title(for: "Color"),
            colorHex: todayColorHex(),
            placeKey: soundKey(for: "Place"),
            placeTitle: title(for: "Place"),
            gemstoneKey: soundKey(for: "Gemstone"),
            gemstoneTitle: title(for: "Gemstone"),
            scentKey: soundKey(for: "Scent"),
            scentTitle: title(for: "Scent"),
            activityKey: soundKey(for: "Activity"),
            activityTitle: title(for: "Activity"),
            careerKey: soundKey(for: "Career"),
            careerTitle: title(for: "Career"),
            relationshipKey: soundKey(for: "Relationship"),
            relationshipTitle: title(for: "Relationship"),
            categoryReasoning: categoryReasoning,
            reasoningSummary: reasoningSummary
        )
        AlynnaWidgetStore.save(snap)
    }

    private func soundKey(for key: String) -> String {
        viewModel.recommendations[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func resolvedWidgetLocation() -> String {
        let location = widgetLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty, location != "Your Current Location" {
            return location
        }

        let recommendationPlace = lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !recommendationPlace.isEmpty {
            return recommendationPlace
        }

        let currentPlace = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentPlace.isEmpty {
            return currentPlace
        }

        return ""
    }

    private struct ReasoningSummarySheet: View {
        @EnvironmentObject var themeManager: ThemeManager
        let text: String

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("detail.reasoning_title")
                        .font(.custom("Merriweather-Bold", size: 18))
                        .foregroundColor(themeManager.primaryText)

                    Text(text)
                        .font(.custom("Merriweather-Regular", size: 15))
                        .lineSpacing(6)
                        .foregroundColor(themeManager.descriptionText)
                        .multilineTextAlignment(.leading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(themeManager.panelFill.opacity(0.6))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter
    }()

    private func timeText(for date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private var lastRecommendationTimeText: String? {
        guard lastRecommendationTimestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: lastRecommendationTimestamp)
        return timeText(for: date)
    }

    private func updateLastRecommendationStampIfReady(
        mantra: String,
        recs: [String: String],
        isDefault: Bool
    ) {
        if isDefault {
            lastRecommendationHasFullSet = false
            return
        }
        let trimmed = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, recs.count >= 8 else {
            lastRecommendationHasFullSet = false
            return
        }
        lastRecommendationTimestamp = Date().timeIntervalSince1970
        lastRecommendationHasFullSet = true
        persistWidgetSnapshotFromViewModel()
    }

    private func makeReasoningSummary(from reasoning: [String: String]) -> String {
        let order = ["Color", "Place", "Gemstone", "Scent", "Activity", "Sound", "Career", "Relationship"]
        let parts = order.compactMap { key -> String? in
            guard let value = reasoning[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return "\(key): \(value)"
        }
        let limited = Array(parts.prefix(2))
        return limited.joined(separator: " | ")
    }

    private func presentMantraShareSheet() {
        guard let image = captureMantraImage() else {
            mantraSaveMessage = "Could not capture the screenshot."
            presentMainViewDialog(
                title: "Share Failed",
                message: mantraSaveMessage,
                symbol: "square.and.arrow.up.badge.exclamationmark"
            )
            return
        }

        presentShareController(with: image)
    }

    private func presentShareController(with image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        guard let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(activity, animated: true)
    }

    private func captureMantraImage() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }

        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let size = window.bounds.size
        let captureView = MantraCaptureView(mantra: viewModel.dailyMantra)
            .environmentObject(starManager)
            .environmentObject(themeManager)

        let controller = UIHostingController(rootView: captureView)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private struct MantraCaptureView: View {
        let mantra: String

        @EnvironmentObject var starManager: StarAnimationManager
        @EnvironmentObject var themeManager: ThemeManager

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    AppBackgroundView(nightMotion: .staticBackground)
                        .ignoresSafeArea()

                    if themeManager.isNight || themeManager.preferredColorScheme == .dark {
                        StaticStarField(size: geometry.size)
                    } else {
                        StaticDayStarField(size: geometry.size)
                    }

                    Text(mantra)
                        .font(AlignaType.expandedMantraFont())
                        .lineSpacing(12)
                        .multilineTextAlignment(.center)
                        .foregroundColor(
                            themeManager.primaryText.opacity(themeManager.isNight ? 0.94 : 0.88)
                        )
                        .padding(.horizontal, geometry.size.width * 0.14)
                        .padding(.top, geometry.size.height * 0.16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .preferredColorScheme(themeManager.preferredColorScheme)
            }
        }

        private struct StaticStar {
            let position: CGPoint
            let size: CGFloat
            let opacity: Double
        }

        private struct StaticStarField: View {
            let size: CGSize
            private let count = 90

            var body: some View {
                ForEach(0..<count, id: \.self) { index in
                    let star = star(for: index, in: size)
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(star.position)
                }
                .allowsHitTesting(false)
            }

            private func star(for index: Int, in size: CGSize) -> StaticStar {
                let x = unit(Double(index) * 12.9898)
                let y = unit(Double(index) * 78.233)
                let s = 1.4 + unit(Double(index) * 45.164) * 2.2
                let o = 0.35 + unit(Double(index) * 93.73) * 0.55

                return StaticStar(
                    position: CGPoint(x: x * size.width, y: y * size.height),
                    size: s,
                    opacity: o
                )
            }

            private func unit(_ seed: Double) -> CGFloat {
                let value = abs(sin(seed) * 43758.5453)
                return CGFloat(value - floor(value))
            }
        }

        private struct StaticDayStar {
            let position: CGPoint
            let size: CGFloat
            let isCross: Bool
            let fill: Color
            let stroke: Color
            let opacity: Double
        }

        private struct StaticDayStarField: View {
            let size: CGSize
            private let count = 20

            var body: some View {
                ForEach(0..<count, id: \.self) { index in
                    let star = star(for: index, in: size)

                    if star.isCross {
                        CrossShape()
                            .stroke(star.stroke.opacity(star.opacity), lineWidth: 1)
                            .frame(width: star.size, height: star.size)
                            .position(star.position)
                    } else {
                        FourPointStarShape()
                            .fill(star.fill.opacity(star.opacity))
                            .overlay(
                                FourPointStarShape()
                                    .stroke(star.stroke.opacity(star.opacity), lineWidth: 1)
                            )
                            .frame(width: star.size, height: star.size)
                            .position(star.position)
                    }
                }
                .allowsHitTesting(false)
            }

            private func star(for index: Int, in size: CGSize) -> StaticDayStar {
                let x = unit(Double(index) * 19.13)
                let y = unit(Double(index) * 57.71)
                let s = 10 + unit(Double(index) * 31.41) * 8
                let o = 0.65 + unit(Double(index) * 83.11) * 0.35
                let isCross = unit(Double(index) * 11.17) > 0.55

                let fillPalette: [Color] = [
                    Color(hex: "#FFF4B3"),
                    Color(hex: "#FFD700"),
                    Color(hex: "#F4D69D")
                ]
                let strokePalette: [Color] = [
                    Color(hex: "#D4A574"),
                    Color(hex: "#C8925F")
                ]

                let fill = fillPalette[index % fillPalette.count]
                let stroke = strokePalette[index % strokePalette.count]

                return StaticDayStar(
                    position: CGPoint(x: x * size.width, y: y * size.height),
                    size: s,
                    isCross: isCross,
                    fill: fill,
                    stroke: stroke,
                    opacity: o
                )
            }

            private func unit(_ seed: Double) -> CGFloat {
                let value = abs(sin(seed) * 43758.5453)
                return CGFloat(value - floor(value))
            }
        }
    }

    // MARK: - WallpaperPreviewView

    /// Full-screen wallpaper preview sheet.
    /// Displays today's color as a gradient background with the mantra in the lower third
    /// and the Alynna brand mark at the bottom.
    private struct WallpaperPreviewView: View {
        let mantra: String
        let colorHex: String

        @Environment(\.dismiss) private var dismiss

        @State private var saveMessage: String = ""
        @State private var showSaveMessage = false
        @State private var isSaving = false

        // Always warm white — matches widget text style regardless of color
        private let textColor = Color(hex: "#F7F3EC")

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Widget-style background
                    WallpaperBackground(hex: colorHex)
                        .ignoresSafeArea()

                    // Mantra — left-aligned, anchored in lower-center area
                    VStack(spacing: 0) {
                        // top spacer pushes mantra to ~55% down
                        Spacer(minLength: geo.size.height * 0.52)

                        Text(mantra)
                            .font(AlignaType.wallpaperMantraFont())
                            .italic(currentRecommendationLanguageCode() != "zh-Hans")
                            .lineSpacing(9)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(textColor)
                            .padding(.leading, geo.size.width * 0.10)
                            .padding(.trailing, geo.size.width * 0.18)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Brand mark — very bottom, icon color matches text
                    HStack(spacing: 6) {
                        if UIImage(named: "alignaSymbol") != nil {
                            Image("alignaSymbol")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(textColor.opacity(0.65))
                        }
                        Text("Alynna")
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .tracking(1.8)
                            .foregroundColor(textColor.opacity(0.65))
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 26)

                    // Dismiss chevron — top left
                    VStack {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(textColor.opacity(0.7))
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 20)
                            .padding(.top, geo.safeAreaInsets.top + 12)
                            Spacer()
                        }
                        Spacer()
                    }
                    .ignoresSafeArea()

                    // Save / Share buttons
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                saveToPhotos(geo: geo)
                            } label: {
                                HStack(spacing: 6) {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.75)
                                            .tint(textColor)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    Text("Save")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(textColor)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                            }
                            .disabled(isSaving)

                            Button {
                                shareWallpaper(geo: geo)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Share")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(textColor)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom + 80)
                    }
                }
                .overlay(alignment: .bottom) {
                    if showSaveMessage {
                        Text(saveMessage)
                            .font(.system(size: 13))
                            .foregroundColor(textColor.opacity(0.85))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                            .padding(.bottom, geo.safeAreaInsets.bottom + 52)
                            .transition(.opacity)
                    }
                }
            }
            .ignoresSafeArea()
        }

        // MARK: Render wallpaper image at native screen scale

        private func renderWallpaperImage(geo: GeometryProxy) -> UIImage? {
            let screenSize = geo.size
            // Use the device's native scale so the saved image is full resolution
            let scale = UIScreen.main.scale
            let renderSize = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)

            let wallpaperView = WallpaperRenderView(
                mantra: mantra,
                colorHex: colorHex,
                size: screenSize
            )

            let controller = UIHostingController(rootView: wallpaperView)
            controller.view.bounds = CGRect(origin: .zero, size: renderSize)
            controller.view.frame = CGRect(origin: .zero, size: renderSize)
            controller.view.backgroundColor = .clear
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1  // renderSize already incorporates screen scale
            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            return renderer.image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
        }

        private func saveToPhotos(geo: GeometryProxy) {
            isSaving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let image = renderWallpaperImage(geo: geo) else {
                    isSaving = false
                    showFeedback("Failed to generate wallpaper.")
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                isSaving = false
                showFeedback("Saved to Photos")
            }
        }

        private func shareWallpaper(geo: GeometryProxy) {
            guard let image = renderWallpaperImage(geo: geo) else {
                showFeedback("Failed to generate wallpaper.")
                return
            }
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                return
            }
            // Walk the presented chain to find the topmost VC (this sheet is already presented)
            var presenter: UIViewController = root
            while let next = presenter.presentedViewController {
                presenter = next
            }
            let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                           y: presenter.view.bounds.maxY,
                                           width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            presenter.present(activity, animated: true)
        }

        private func showFeedback(_ msg: String) {
            saveMessage = msg
            withAnimation { showSaveMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showSaveMessage = false }
            }
        }
    }

    // MARK: - WallpaperBackground (shared widget-style background)

    private struct WallpaperBackground: View {
        let hex: String

        var body: some View {
            GeometryReader { geo in
                // Widget-style: desaturated + darkened base, linear top→bottom gradient,
                // topLeading highlight, bottom vignette, subtle grain
                let top    = Self.adjusted(hex, darken: 0.10, desaturate: 0.10)
                let bottom = Self.adjusted(hex, darken: 0.28, desaturate: 0.18)
                let base   = Self.adjusted(hex, darken: 0.18, desaturate: 0.14)
                let minDim = min(geo.size.width, geo.size.height)

                ZStack {
                    base
                    LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                    // topLeading soft highlight
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: minDim * 1.1
                    )
                    // bottom vignette
                    RadialGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.28)]),
                        center: .center,
                        startRadius: minDim * 0.3,
                        endRadius: max(geo.size.width, geo.size.height) * 0.95
                    )
                    // grain texture
                    Canvas { ctx, canvasSize in
                        for i in 0..<160 {
                            let x = unit(Double(i) * 12.9898) * canvasSize.width
                            let y = unit(Double(i) * 78.233) * canvasSize.height
                            let r = 0.4 + unit(Double(i) * 45.164) * 0.9
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                     with: .color(Color.white.opacity(0.07)))
                        }
                    }
                    .blendMode(.softLight)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }

        private static func adjusted(_ hex: String, darken: Double, desaturate: Double) -> Color {
            let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: h).scanHexInt64(&int)
            guard h.count == 6 else { return Color(hex: hex) }
            let r = Double(int >> 16) / 255
            let g = Double((int >> 8) & 0xFF) / 255
            let b = Double(int & 0xFF) / 255
            let avg = (r + g + b) / 3.0
            let dr = (r * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
            let dg = (g * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
            let db = (b * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
            return Color(.sRGB, red: min(dr, 1), green: min(dg, 1), blue: min(db, 1), opacity: 1)
        }

        private func unit(_ seed: Double) -> Double {
            let v = abs(sin(seed) * 43758.5453)
            return v - floor(v)
        }
    }

    // MARK: - WallpaperRenderView (off-screen render target, no safe area)

    private struct WallpaperRenderView: View {
        let mantra: String
        let colorHex: String
        let size: CGSize

        private let textColor = Color(hex: "#F7F3EC")

        var body: some View {
            ZStack(alignment: .bottom) {
                WallpaperBackground(hex: colorHex)
                    .frame(width: size.width, height: size.height)

                // Mantra — left-aligned at ~55% down
                VStack(spacing: 0) {
                    Spacer(minLength: size.height * 0.52)
                    Text(mantra)
                        .font(AlignaType.wallpaperMantraFont())
                        .italic(currentRecommendationLanguageCode() != "zh-Hans")
                        .lineSpacing(9)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(textColor)
                        .padding(.leading, size.width * 0.10)
                        .padding(.trailing, size.width * 0.18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .frame(width: size.width, height: size.height)

                // Brand mark
                HStack(spacing: 6) {
                    if UIImage(named: "alignaSymbol") != nil {
                        Image("alignaSymbol")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(textColor.opacity(0.65))
                    }
                    Text("Alynna")
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .tracking(1.8)
                        .foregroundColor(textColor.opacity(0.65))
                }
                .padding(.bottom, 40)
            }
            .frame(width: size.width, height: size.height)
        }
    }


    
    // 冷启动只看"是否已登录 + 本地标记"来分流；不再在这里查 Firestore 决定是否强拉 Onboarding。
    // === 替换你原来的 startInitialLoad()（整段替换） ===
    private func startInitialLoad() {
        isMantraReady = false

        #if DEBUG
        if _isPreview { bootPhase = .main; return }
        #endif
        // 冷启动先“等用户恢复”，最多等一小会（例如 6 秒）
        waitForAuthenticatedUserThenBoot(maxWait: 6.0)
    }

    // NEW: 等待 Firebase 恢复 currentUser 后再走原有分流逻辑
    private func waitForAuthenticatedUserThenBoot(maxWait: TimeInterval) {
        // 每天首次启动：重置 watchdog 计数/锁
        resetDailyWatchdogIfNeeded()

        if let user = Auth.auth().currentUser, !authWaitTimedOut {
            resolveBootPath(for: user)
            return
        }

        // 没有 currentUser：安装监听，等待恢复
        if authListenerHandle == nil {
            authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                if user != nil {
                    // 恢复到用户了 → 移除监听并启动
                    if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
                    authListenerHandle = nil
                    authWaitTimedOut = false
                    waitForAuthenticatedUserThenBoot(maxWait: 0) // 递归调用进入分流
                }
            }
        }

        // 兜底超时：防止无限等。到时仍未恢复用户，就按“未登录”进入。
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, maxWait)) {
            guard Auth.auth().currentUser == nil else { return }
            authWaitTimedOut = true
            if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
            authListenerHandle = nil
            // 超时还没恢复用户 → 走未登录 OpeningPage
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            withAnimation(.easeInOut) { bootPhase = .onboarding }
        }
    }

    private func resolveBootPath(for user: User) {
        if didResolveBootPath { return }
        didResolveBootPath = true

        // A) 未登录（极端兜底）
        if user.uid.isEmpty {
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            withAnimation(.easeInOut) { bootPhase = .onboarding }
            return
        }

        let ref = Firestore.firestore().collection("users").document(user.uid)
        let source: FirestoreSource = didDeleteAccount ? .server : .default
        ref.getDocument(source: source) { snapshot, error in
            let data = snapshot?.data()
            let nickname = (data?["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let hasProfile = data != nil && !nickname.isEmpty

            DispatchQueue.main.async {
                if !nickname.isEmpty {
                    privilegedNickname = nickname
                    viewModel.nickname = nickname
                }
                if let _ = error {
                    if didDeleteAccount {
                        didDeleteAccount = false
                        ref.getDocument { snapshot, error in
                            DispatchQueue.main.async {
                                if let _ = error {
                                    didResolveBootPath = false
                                    if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                                        withAnimation(.easeInOut) { bootPhase = .onboarding }
                                        return
                                    }
                                    shouldOnboardAfterSignIn = false
                                    proceedNormalBoot()
                                    return
                                }

                                let data = snapshot?.data()
                                let nickname = (data?["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let hasProfile = data != nil && !nickname.isEmpty

                                if !nickname.isEmpty {
                                    privilegedNickname = nickname
                                    viewModel.nickname = nickname
                                }

                                if hasProfile {
                                    hasCompletedOnboarding = true
                                    shouldOnboardAfterSignIn = false
                                    proceedNormalBoot()
                                    return
                                }

                                if shouldOnboardAfterSignIn || !hasCompletedOnboarding {
                                    withAnimation(.easeInOut) { bootPhase = .onboarding }
                                } else {
                                    proceedNormalBoot()
                                }
                            }
                        }
                        return
                    }

                    // 读取失败则退回本地标记逻辑
                    didResolveBootPath = false
                    if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                        withAnimation(.easeInOut) { bootPhase = .onboarding }
                        return
                    }
                    shouldOnboardAfterSignIn = false
                    proceedNormalBoot()
                    return
                }

                if didDeleteAccount {
                    didDeleteAccount = false
                }

                if hasProfile {
                    hasCompletedOnboarding = true
                    shouldOnboardAfterSignIn = false
                    proceedNormalBoot()
                    return
                }

                if shouldOnboardAfterSignIn || !hasCompletedOnboarding {
                    withAnimation(.easeInOut) { bootPhase = .onboarding }
                } else {
                    proceedNormalBoot()
                }
            }
        }
    }

    // NEW: 按自然日重置 watchdog 相关的 @AppStorage
    private func resetDailyWatchdogIfNeeded() {
        let today = todayString()
        if watchdogDay != today {
            watchdogDay = today
            todayAutoRefetchAttempts = 0
            todayAutoRefetchDone = ""
            todayFetchLock = ""
        }
    }

    // ====== MainView 内新增 ======
    private func hydrateBirthFromProfileIfNeeded(_ done: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { done(); return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        ref.getDocument { snap, _ in
            defer { done() }
            guard let data = snap?.data() else { return }
            

            // birth date
            if let ts = data["birthday"] as? Timestamp {
                viewModel.birth_date = ts.dateValue()
            } else if let s = data["birthDate"] as? String,
                      let d = parseBirthDateString(s) {
                viewModel.birth_date = d
            }


            // birth time（统一通过 timeToDateFlexible 解析成本地时区的“时分锚定”Date）
            if let t = data["birthTime"] as? String, let d = timeToDateFlexible(t) {
                viewModel.birth_time = d
            }

            // ✅ 出生经纬度 → 注入 viewModel（供上升星座使用）
            if let lat = data["birthLat"] as? CLLocationDegrees,
               let lng = data["birthLng"] as? CLLocationDegrees,
               lat != 0 || lng != 0 {
                viewModel.birthCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }


    /// 每次 app 进入前台时调用，检测当前内容是否需要通过 LoadingView 补救更新。
    /// 规则：
    ///   1. isDefault mantra → 立即走 LoadingView（最高优先级）
    ///   2. 更新时间之后 + 内容是昨天的 → 走 LoadingView
    ///   3. 更新时间之前 + 内容是昨天的 → 不处理（正常，还没到更新时间）
    ///   4. 内容是今天的且非 default → 不处理
    private func evaluateOnLaunch() {
        // 只在已进入主界面后才评估
        guard bootPhase == .main else { return }
        guard Auth.auth().currentUser != nil else { return }

        let today = todayString()

        // 情况 1：当前是 default mantra，立即补救
        if isDefaultRecommendation {
            print("🔄 evaluateOnLaunch: 检测到 default mantra，触发 LoadingView 补救")
            triggerRemedialLoading()
            return
        }

        // 情况 2：内容日期不是今天（且当前时间已过更新时间）
        let recDay = lastRecommendationHasFullSet
            ? effectiveDayString(for: Date(timeIntervalSince1970: lastRecommendationTimestamp))
            : ""
        if recDay != today {
            // 检查当前时间是否已过更新时间
            let now = Date()
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: now)
            let currentMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let updateMinutes = dailyRhythmUpdateHour * 60 + dailyRhythmUpdateMinute
            if currentMinutes >= updateMinutes {
                print("🔄 evaluateOnLaunch: 内容是昨天的且已过更新时间，触发 LoadingView 补救")
                triggerRemedialLoading()
            } else {
                print("ℹ️ evaluateOnLaunch: 内容是昨天的但还未到更新时间，跳过")
            }
        }
    }

    /// 触发补救性 LoadingView 更新（不计入 manual refresh 配额）
    private func triggerRemedialLoading() {
        guard !isFetchingToday else {
            print("ℹ️ triggerRemedialLoading: 已有请求在途，跳过")
            return
        }
        // 重置 watchdog 以允许新一轮重试
        let today = todayString()
        if watchdogDay != today {
            watchdogDay = today
            todayAutoRefetchAttempts = 0
            todayAutoRefetchDone = ""
            todayFetchLock = ""
        }
        isManualRefreshFlow = false
        didCompletePersonalCheckIn = false
        isMantraReady = false
        withAnimation(.easeInOut) { bootPhase = .loading }
    }

    // 原先 startInitialLoad 的主体逻辑移到这里（不修改其内容）
    private func proceedNormalBoot() {
        let group = DispatchGroup()

        // FIX: 先把生日/时间从用户档案同步到 viewModel
        group.enter()
        hydrateBirthFromProfileIfNeeded { group.leave() }

        let today = todayString()
        group.enter()
        loadTodayRecommendation(day: today, source: .default, allowRemoteFallback: false) { group.leave() }

        group.notify(queue: .main) {
            self.reasoningStore.load(for: Date())
            self.isBootDataReady = true
            attemptBootAdvance()
        }
    }


    private func ensureDailyCurrentPlaceSaved(completion: @escaping () -> Void) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // 当天已经写过了，直接过
        if lastCurrentPlaceUpdate == today {
            completion()
            return
        }

        // 等待定位（最多等 8 秒）
        let start = Date()
        let waitLimit: TimeInterval = 8.0

        func attempt() {
            if let coord = locationManager.currentLocation {
                // 有坐标 → 反地理解析城市名 → 写入 Firestore
                getAddressFromCoordinate(coord) { city in
                    let place = city ?? "Unknown"
                    upsertUserCurrentPlace(place: place, coord: coord) { ok in
                        if ok { lastCurrentPlaceUpdate = today }
                        completion()
                    }
                }
                return
            }

            // 超时兜底：没有坐标也尽量落一次（Unknown），不阻塞启动
            if Date().timeIntervalSince(start) > waitLimit {
                upsertUserCurrentPlace(place: "Unknown", coord: nil) { ok in
                    if ok { lastCurrentPlaceUpdate = today }
                    completion()
                }
                return
            }

            // 继续等
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { attempt() }
        }

        attempt()
    }
    private func upsertUserCurrentPlace(
        place: String,
        coord: CLLocationCoordinate2D?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            print("❌ 未登录，跳过写入 currentPlace")
            completion(false)
            return
        }
        let db = Firestore.firestore()

        var fields: [String: Any] = ["currentPlace": place]
        if let c = coord {
            fields["currentLat"] = c.latitude
            fields["currentLng"] = c.longitude
        }

        func write(to ref: DocumentReference) {
            ref.setData(fields, merge: true) { err in
                if let err = err {
                    print("❌ 更新 currentPlace 失败：\(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ 已更新用户 currentPlace: \(place)")
                    completion(true)
                }
            }
        }

        // 1) users 按 uid
        db.collection("users").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s1, _ in
            if let doc = s1?.documents.first { write(to: doc.reference); return }

            // 2) user 按 uid
            db.collection("user").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s2, _ in
                if let doc2 = s2?.documents.first { write(to: doc2.reference); return }

                // 3) users / user 按 email（如有）
                if let email = user.email {
                    db.collection("users").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s3, _ in
                        if let d3 = s3?.documents.first { write(to: d3.reference); return }

                        db.collection("user").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s4, _ in
                            if let d4 = s4?.documents.first { write(to: d4.reference); return }

                            // 4) 都没有 → 在 users 新建最小档案
                            var payload = fields
                            payload["uid"] = user.uid
                            payload["email"] = email
                            payload["createdAt"] = Timestamp()
                            db.collection("users").addDocument(data: payload) { err in
                                if let err = err {
                                    print("❌ 创建用户文档失败：\(err.localizedDescription)")
                                    completion(false)
                                } else {
                                    print("✅ 已创建用户文档并写入 currentPlace")
                                    completion(true)
                                }
                            }
                        }
                    }
                } else {
                    // 没有 email：用 uid 最小化建档
                    var payload = fields
                    payload["uid"] = user.uid
                    payload["createdAt"] = Timestamp()
                    db.collection("users").addDocument(data: payload) { err in
                        if let err = err {
                            print("❌ 创建用户文档失败：\(err.localizedDescription)")
                            completion(false)
                        } else {
                            print("✅ 已创建用户文档并写入 currentPlace")
                            completion(true)
                        }
                    }
                }
            }
        }
    }




    /// Polls viewModel.recommendations until non-empty (or timeout)
    private func waitUntilRecommendationsReady(
        timeout: TimeInterval = 30,
        poll: TimeInterval = 0.2,
        softTimeout: TimeInterval = 12,
        onReady: @escaping () -> Void
    ) {
        let start = Date()
        var didShowStrongHint = false
        func check() {
            if !viewModel.recommendations.isEmpty {
                onReady()
                return
            }
            let elapsed = Date().timeIntervalSince(start)
            if !didShowStrongHint, elapsed > softTimeout {
                didShowStrongHint = true
                if isGenerationInProgress {
                    showGenerationStrongHint = true
                    showCenterToast("Generating today’s mantra and rhythm", duration: 2.6, includeTime: false)
                }
            }
            if elapsed > timeout {
                if viewModel.recommendations.isEmpty {
                    isGenerationInProgress = false
                    isUsingPreviousResult = false
                    showGenerationStrongHint = false
                    showMainGenerationOverlay = false
                    ensureDefaultsIfMissing()
                }
                // Timeout: still move on (you can choose to stay on loading if you prefer)
                onReady()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + poll, execute: check)
        }
        check()
    }

    private func attemptBootAdvance() {
        guard isBootDataReady, didCompletePersonalCheckIn else { return }
        withAnimation(.easeInOut) { bootPhase = .main }
        pendingMantraExpansion = true
        markMantraReadyIfPossible()
        if shouldShowBootLoading {
            shouldShowBootLoading = false
        }
    }

    private func handleManualRefreshTap() {
        guard canProceedWithLocationRefresh() else { return }
        guard manualRefreshAllowed() else {
            refreshCooldownMessage = refreshCooldownText()
            presentMainViewDialog(
                title: "Update Unavailable",
                message: refreshCooldownMessage,
                symbol: "clock.badge.exclamationmark"
            )
            return
        }
        isManualRefreshFlow = true
        didCompletePersonalCheckIn = false
        isMantraReady = false
        bootPhase = .loading
    }

    private func manualRefreshAllowed() -> Bool {
        if isPrivilegedUser { return true }
        let now = Date().timeIntervalSince1970
        return now - lastManualRefreshTimestamp >= 12 * 60 * 60
    }

    private func refreshCooldownText() -> String {
        guard lastManualRefreshTimestamp > 0 else {
            return "To keep each refresh intentional, the next one will be available 12 hours later. We’re actively developing a subscription option with expanded access. Thank you for your patience."
        }
        let last = Date(timeIntervalSince1970: lastManualRefreshTimestamp)
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let lastText = formatter.string(from: last)
        return "Your last rhythm update was at \(lastText). To keep each refresh intentional, the next one will be available 12 hours later. We’re actively developing a subscription option with expanded access. Thank you for your patience."
    }

    private func expandMantraIfNeeded() {
        guard pendingMantraExpansion else { return }
        pendingMantraExpansion = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isMantraExpanded = true
        }
    }

    private func markMantraReadyIfPossible() {
        let trimmed = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard bootPhase == .main, !trimmed.isEmpty else { return }
        if !isMantraReady {
            isMantraReady = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expandMantraIfNeeded()
        }
    }

    private func triggerMantraExpansionHapticIfNeeded() {
        guard bootPhase == .main, isMantraReady else { return }
        let today = todayString()
        guard mantraExpandHapticDay != today else { return }
        mantraExpandHapticDay = today

        let light = UIImpactFeedbackGenerator(style: .light)
        light.prepare()
        light.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.prepare()
            soft.impactOccurred()
        }
    }

    private func beginGenerationFlow() {
        isGenerationInProgress = true
        showGenerationStrongHint = false
        isDefaultRecommendation = false
        if focusGenerationTagID == nil {
            configureDailyGenerationOverlay()
        }
        scheduleGenerationOverlayHints()
        let hasContent = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.recommendations.isEmpty
            || lastRecommendationHasFullSet
        isUsingPreviousResult = hasContent
    }

    private func completeGenerationIfNeeded(isDefault: Bool) {
        guard isGenerationInProgress else { return }
        generationOverlaySequence += 1
        isGenerationInProgress = false
        isUsingPreviousResult = false
        showGenerationStrongHint = false
        showMainGenerationOverlay = false
        focusGenerationTagID = nil
        if !isDefault {
            if bootPhase == .main {
                triggerGenerationHapticIfNeeded()
                showCenterToast("Updated for today", duration: 2.2, includeTime: false)
            } else {
                pendingGenerationToast = true
            }
        }
    }

    private func triggerGenerationHapticIfNeeded() {
        let light = UIImpactFeedbackGenerator(style: .light)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let success = UINotificationFeedbackGenerator()

        light.prepare()
        medium.prepare()
        success.prepare()

        light.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            medium.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            success.notificationOccurred(.success)
        }
    }

    private func showCenterToast(_ message: String, duration: TimeInterval, includeTime: Bool = true) {
        DispatchQueue.main.async {
            if includeTime {
                generationToastMessage = "\(message) • \(timeText(for: Date()))"
            } else {
                generationToastMessage = message
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88, blendDuration: 0.1)) {
                showGenerationToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showGenerationToast = false
                }
            }
        }
    }

    private func triggerGridIconAnimation() {
        showGridItems = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.35)) {
                showGridItems = true
            }
        }
    }

    private func toggleMantraExpansion() {
        guard isMantraReady else { return }
        let wasExpanded = isMantraExpanded
        if wasExpanded && mantraGuidanceHintTapCount < 3 {
            mantraGuidanceHintTapCount += 1
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            isMantraExpanded.toggle()
        }
    }

    var body: some View {
        Group {
            switch bootPhase {
            case .loading:
                LoadingView(
                    onStartLoading: {
                        if isManualRefreshFlow {
                            return
                        }
                        startInitialLoad()
                    },
                    onPersonalComplete: { didProvidePersonal in
                        if isManualRefreshFlow {
                            forceRefetchDailyIfNotLocked()
                            if showMainGenerationOverlay {
                                isBootDataReady = true
                            }
                        } else if showMainGenerationOverlay && !hasRecentRecommendation {
                            forceRefetchDailyIfNotLocked()
                            if showMainGenerationOverlay {
                                isBootDataReady = true
                            }
                        } else if hasRecentRecommendation {
                            showMainGenerationOverlay = false
                            isBootDataReady = true
                        } else {
                            showMainGenerationOverlay = false
                        }
                        if isManualRefreshFlow {
                            lastManualRefreshTimestamp = Date().timeIntervalSince1970
                            isManualRefreshFlow = false
                            isBootDataReady = true
                        }
                        didCompletePersonalCheckIn = true
                        attemptBootAdvance()
                    },
                    forceFullLoading: isManualRefreshFlow,
                    locationManager: locationManager
                )
                .ignoresSafeArea()
                        
            case .onboarding:
                NavigationStack {
                    if shouldOnboardAfterSignIn {
                        // 注册后正式进入引导：Step1
                        OnboardingStep0(viewModel: viewModel)
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    } else {
                        // 冷启动未登录：先到 OpeningPage（包含 Sign Up / Log In）
                        FrontPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    }
                }
            case .main:
                            mainContent // (extract your existing NavigationStack content into a computed var)
                        }
                    }
                    .overlay {
                        if bootPhase == .main && showMainGenerationOverlay {
                            ZStack {
                                Color.black.opacity(themeManager.isNight ? 0.34 : 0.18)
                                    .ignoresSafeArea()

                                AlynnaGenerationOverlayCard(
                                    title: mainGenerationOverlayTitle,
                                    message: mainGenerationOverlayMessage,
                                    showDots: true
                                )
                                .environmentObject(themeManager)
                            }
                            .transition(.opacity)
                        }
                    }
                    .onAppear {
                        // run once on cold start
                        locationPermissionCoordinator.refreshAuthorizationStatus()
                        if !didBootVisuals {
                            didBootVisuals = true
                            starManager.animateStar = true
                            themeManager.appBecameActive()

                            let trimmed = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                cachedDailyMantra = trimmed
                                if dailyMantraNotificationEnabled {
                                    syncNotificationTimeToRhythmUpdate()
                                    MantraNotificationManager.scheduleDaily(
                                        mantra: trimmed,
                                        hour: dailyMantraNotificationHour,
                                        minute: dailyMantraNotificationMinute
                                    )
                                }
                            }
                        }

                        if shouldShowBootLoading {
                            bootPhase = .loading
                        }

                        // 修订3：冷启动后也执行跨天/default 检测
                        evaluateOnLaunch()

                        if shouldCollapseMantraOnReturn {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMantraExpanded = false
                            }
                            shouldCollapseMantraOnReturn = false
                        }
                    }
                    .onChange(of: mainNavigationPath) { _, newValue in
                        if newValue.isEmpty, shouldCollapseMantraOnReturn {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMantraExpanded = false
                            }
                            shouldCollapseMantraOnReturn = false
                        }
                    }
                    .onChange(of: viewModel.dailyMantra) { _, newValue in
                        cachedDailyMantra = newValue
                        if dailyMantraNotificationEnabled {
                            syncNotificationTimeToRhythmUpdate()
                            MantraNotificationManager.scheduleDaily(
                                mantra: newValue,
                                hour: dailyMantraNotificationHour,
                                minute: dailyMantraNotificationMinute
                            )
                        }
                    }
                    .onChange(of: isMantraExpanded) { _, expanded in
                        if expanded {
                            showGridItems = false
                            triggerMantraExpansionHapticIfNeeded()
                        } else {
                            triggerGridIconAnimation()
                        }
                    }
                    .onChange(of: viewModel.recommendations) { _, newValue in
                        let key = (newValue["Sound"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !key.isEmpty, key != lastPrefetchedSoundKey {
                            lastPrefetchedSoundKey = key
                            soundPlayer.prefetch(named: key)
                        }
                        if !isMantraExpanded {
                            triggerGridIconAnimation()
                        }
                    }
                    .onChange(of: shouldExpandMantraFromNotification) { _, newValue in
                        guard newValue else { return }
                        mainNavigationPath = NavigationPath()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMantraExpanded = true
                        }
                        shouldExpandMantraFromNotification = false
                    }
                    .onChange(of: locationPermissionCoordinator.authorizationStatus) { _, status in
                        if (status == .authorizedAlways || status == .authorizedWhenInUse),
                           showMainViewDialog,
                           mainViewDialogIsLocationPermission {
                            dismissMainViewDialog()
                        }
                    }
                    .onChange(of: locationPermissionCoordinator.settingsReturnCount) { _, _ in
                        if showMainViewDialog, mainViewDialogIsLocationPermission {
                            dismissMainViewDialog()
                        }
                    }
                    // 修订3：监听 app 从后台进入前台，执行跨天/default 检测
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active {
                            evaluateOnLaunch()
                        }
                    }
                }
    private func fetchAllRecommendationTitles() {
        #if DEBUG
        if _isPreview { return }
        #endif
        
        let db = Firestore.firestore()

        for (rawCategory, rawDoc) in viewModel.recommendations {
            // 统一得到规范写法（如果已经是规范写法，也会直接返回自身）
            guard let canon = canonicalCategory(from: rawCategory) ?? canonicalCategory(from: rawCategory.capitalized) ?? rawCategory as String? else {
                print("⚠️ 跳过未知类别：\(rawCategory)")
                continue
            }
            guard let collection = firebaseCollectionName(for: canon) else {
                print("⚠️ 未知集合映射：\(canon)")
                continue
            }

            let documentName = sanitizeDocumentName(rawDoc)
            guard !documentName.isEmpty else {
                print("⚠️ 跳过空文档名（\(canon)）")
                continue
            }

            db.collection(collection).document(documentName).getDocument { snapshot, error in
                if let error = error {
                    print("❌ 加载 \(canon) 标题失败: \(error)")
                    return
                }
                if let data = snapshot?.data(), let title = data["title"] as? String {
                    DispatchQueue.main.async {
                        self.recommendationTitles[canon] = title // 以规范写法作键
                        self.persistWidgetSnapshotFromViewModel()
                    }
                } else {
                    print("⚠️ \(canon)/\(documentName) 无 title 字段或文档不存在")
                }
            }
        }
    }

    /// 启动“保底看门狗”：若 delay 秒后仍未拿到 mantra 或推荐，则强制走一次 FastAPI 重拉
    // === 替换你原有的 startAutoRefetchWatchdog(delay:)（整段替换） ===
    private func startAutoRefetchWatchdog(delay: TimeInterval = 8.0) {
        // 只安排一次根任务
        guard !autoRefetchScheduled else { return }
        autoRefetchScheduled = true

        func scheduleNext(after: TimeInterval) {
            // 只有拿到非默认结果才停止自动重试
            let mantraReady = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let recsReady   = !viewModel.recommendations.isEmpty
            if mantraReady && recsReady && !isDefaultRecommendation { return }

            // 达到上限就停
            if todayAutoRefetchAttempts >= maxRefetchAttempts { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + after) {
                // 进入具体一次尝试：再次判断是否已经拿到非默认结果
                let readyNow = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.recommendations.isEmpty
                            && !isDefaultRecommendation
                guard !readyNow else { return }

                // 触发一次强制重拉
                print("🛡️ Watchdog attempt #\(todayAutoRefetchAttempts + 1)")
                forceRefetchDailyIfNotLocked()

                // 增加计数并安排下一次（指数退避，封顶 60s）
                todayAutoRefetchAttempts += 1
                let nextDelay = min(60.0, max(6.0, after * 1.8))
                scheduleNext(after: nextDelay)
            }
        }

        scheduleNext(after: delay <= 0 ? initialRefetchDelay : delay)
    }


    /// 强制当日重拉（跳过“今日已有推荐”的判断），仍复用今日互斥锁与定位等待
    // === 替换你原有的 forceRefetchDailyIfNotLocked()（整段替换） ===
    private func forceRefetchDailyIfNotLocked() {
        guard let uid = Auth.auth().currentUser?.uid else {
            showMainGenerationOverlay = false
            print("❌ 未登录，无法强制重拉"); return
        }
        guard canProceedWithLocationRefresh() else {
            showMainGenerationOverlay = false
            return
        }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 若已有在途请求，就不重复发；仅有同日旧锁但当前没有活跃请求时，视为 stale lock
        if isFetchingToday {
            print("⏳ Watchdog: 今日请求已在进行中，跳过强制重拉")
            return
        }
        if todayFetchLock == today {
            print("⚠️ 检测到 stale todayFetchLock，清除后继续重拉")
            todayFetchLock = ""
        }

        beginGenerationFlow()
        todayFetchLock = today
        isFetchingToday = true

        // Watchdog 重拉也需要定位；没有的话先申请并等待
        if locationManager.currentLocation == nil {
            locationManager.requestLocation()
        }
        waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
    }


    
    // 当天字符串
    private func todayString() -> String {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        let updateMinutes = dailyRhythmUpdateHour * 60 + dailyRhythmUpdateMinute

        let effectiveDate: Date
        if currentMinutes < updateMinutes {
            effectiveDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else {
            effectiveDate = now
        }

        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: effectiveDate)
    }

    // 当天唯一 DocID：uid_yyyy-MM-dd
    private func todayDocRef(uid: String, day: String) -> DocumentReference {
        Firestore.firestore()
            .collection("daily_recommendation")
            .document("\(uid)_\(day)")
    }
    
    /// ✅ 当 FastAPI 生成失败时，把本地默认推荐也写入 daily_recommendation（用于 Timeline/Calendar 回看）
    /// - Note: 使用同一个 docId = uid_yyyy-MM-dd，后续如果 FastAPI 成功，会覆盖掉默认值。
    private func saveDefaultDailyRecommendationToCalendar(
        userId: String,
        today: String,
        docRef: DocumentReference,
        reason: String
    ) {
        // 只写“规范写法”的 key，保证 Timeline/DailyViewModel 能正常读取
        let normalized: [String: String] = DesignRecs.docs.reduce(into: [:]) { acc, kv in
            if let canon = canonicalCategory(from: kv.key) {
                acc[canon] = sanitizeDocumentName(kv.value)
            }
        }

        var data: [String: Any] = normalized
        data["uid"] = userId
        data["createdAt"] = today
        data["mantra"] = DesignRecs.mantra
        
        let fallbackPlace = {
            let p1 = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p1.isEmpty { return p1 }
            let p2 = lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p2.isEmpty { return p2 }
            return "Unknown"
        }()
        data["generatedPlace"] = fallbackPlace

        DispatchQueue.main.async {
            self.lastRecommendationDate = today
            self.lastRecommendationPlace = fallbackPlace
        }

        
        data["isDefault"] = true
        data["fallbackReason"] = reason
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        // ✅ NEW: default per-category reasoning map
        var reasoningMap: [String: String] = [:]
        for canonKey in normalized.keys {
            reasoningMap[canonKey] = defaultReasoning(for: canonKey)
        }
        data["reasoning"] = reasoningMap

        docRef.setData(data, merge: true) { err in
            if let err = err {
                print("❌ 保存默认 daily_recommendation 失败：\(err)")
            } else {
                print("✅ 已保存默认推荐到 Calendar（\(reason)）")
            }
        }
    }

    // 等待定位后只发一次请求（最多等 8 秒）
    private func waitForLocationThenRequest(uid: String, today: String, docRef: DocumentReference) {
        let start = Date()
        let limit: TimeInterval = 8.0

        func attempt() {
            let authorizationStatus = locationManager.authorizationStatus
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                presentLocationPermissionRequiredAlert()
                todayFetchLock = ""
                isFetchingToday = false
                completeGenerationIfNeeded(isDefault: true)
                return
            }
            if let coord = locationManager.currentLocation {
                fetchFromFastAPIAndSave(coord: coord, userId: uid, today: today, docRef: docRef)
                return
            }
            if Date().timeIntervalSince(start) > limit {
                print("⚠️ 超时仍未拿到坐标，本次放弃生成；将默认推荐写入 Calendar 以便回看")
                saveDefaultDailyRecommendationToCalendar(
                    userId: uid,
                    today: today,
                    docRef: docRef,
                    reason: "location_timeout"
                )
                todayFetchLock = ""  // 释放互斥锁
                isFetchingToday = false
                completeGenerationIfNeeded(isDefault: true)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: attempt)
        }
        attempt()
    }

    

    private func fetchAndSaveRecommendationIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 用户未登录，跳过获取推荐"); return
        }
        guard canProceedWithLocationRefresh() else { return }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 单日互斥：仅阻止真实在途请求；同日旧锁但当前无活跃请求时清理后继续
        if isFetchingToday {
            print("⏳ 今日拉取已在进行或已加锁，跳过二次触发")
            return
        }
        if todayFetchLock == today {
            print("⚠️ 检测到 stale todayFetchLock，清除后继续今日拉取")
            todayFetchLock = ""
        }

        // 直接命中 docId 判断是否已有今日推荐（避免并发竞态）
        docRef.getDocument { snap, err in
            if let err = err {
                print("❌ 查询今日推荐失败：\(err.localizedDescription)")
                return
            }
            if let snap = snap, snap.exists {
                let data = snap.data() ?? [:]

                // If today's doc exists but has no reasoning, regenerate to backfill reasoning.
                // This fixes the case where you deleted/recreated a doc while backend didn't
                // provide mapping, or an older writer created the doc without reasoning.
                // Also regenerate when isDefault == true: the fallback doc also writes a
                // reasoning map, so without this check a failed API call would permanently
                // block regeneration on every subsequent boot.
                let isDefault = (data["isDefault"] as? Bool) == true
                let hasRealReasoning = !isDefault && ((data["reasoning"] != nil) || (data["mapping"] != nil))
                if hasRealReasoning {
                    print("📌 今日已有推荐（docId 命中），不重复生成")
                    lastRecommendationDate = today
                    loadTodayRecommendation(day: today)
                    return
                } else {
                    let reason = isDefault ? "isDefault=true，触发重拉覆盖默认值" : "缺少 reasoning/mapping，将触发重拉以补全"
                    print("⚠️ 今日 doc 存在但需要重拉：\(reason)")
                    // fall through to generation path below
                }
            }


            // 尚无今日记录 → 加锁并等待定位就绪后只发一次
            guard canProceedWithLocationRefresh() else { return }
            todayFetchLock = today
            isFetchingToday = true
            if locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
            waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
        }
    }

    
    private func fetchFromFastAPIAndSave(
        coord: CLLocationCoordinate2D,
        userId: String,
        today: String,
        docRef: DocumentReference
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        // Build base payload
        var payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": coord.latitude,
            "longitude": coord.longitude
        ]
        attachRecommendationLanguage(to: &payload)

        // Attach place signals captured during the loading screen, if available
        if !viewModel.currentPlace.isEmpty                        { payload["current_place"]      = viewModel.currentPlace }
        if let v = viewModel.weatherCondition                     { payload["weather_condition"]   = v }
        if let v = viewModel.temperature                          { payload["temperature"]         = v }
        if let v = viewModel.windDirection                        { payload["wind_direction"]      = v }
        if let v = viewModel.windSpeed                            { payload["wind_speed"]          = v }
        if let v = viewModel.humidity                             { payload["humidity"]            = v }
        if let v = viewModel.pressure                             { payload["pressure"]            = v }
        if let v = viewModel.airQualityAQI                        { payload["air_quality_aqi"]     = v }
        if let v = viewModel.airQualityPM25                       { payload["air_quality_pm2_5"]   = v }
        if let v = viewModel.waterPercent                         { payload["water_percent"]       = v }
        if let v = viewModel.greenPercent                         { payload["green_percent"]       = v }
        if let v = viewModel.builtPercent                         { payload["built_percent"]       = v }
        if let v = viewModel.checkInMood                          { payload["mood"]                = v }
        if let v = viewModel.checkInStress                        { payload["stress"]              = v }
        if let v = viewModel.checkInSleep                         { payload["sleep"]               = v }

        let trimmedNotes = viewModel.checkInNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty                                  { payload["personal_notes"]      = trimmedNotes }

        print("[PayloadOut] place_signals → current_place=\(viewModel.currentPlace) condition=\(viewModel.weatherCondition ?? "nil") temp=\(viewModel.temperature.map { String($0) } ?? "nil") wind=\(viewModel.windDirection ?? "nil")@\(viewModel.windSpeed.map { String($0) } ?? "nil") humidity=\(viewModel.humidity.map { String($0) } ?? "nil") pressure=\(viewModel.pressure.map { String($0) } ?? "nil")")

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            saveDefaultDailyRecommendationToCalendar(
                userId: userId,
                today: today,
                docRef: docRef,
                reason: "invalid_url"
            )
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            saveDefaultDailyRecommendationToCalendar(
                userId: userId,
                today: today,
                docRef: docRef,
                reason: "json_serialization_error"
            )
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer {                    // 不管成功失败都释放“今日锁”
                DispatchQueue.main.async {
                    todayFetchLock = ""
                    isFetchingToday = false
                }
            }

            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "network_error"
                )
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("❌ 非 HTTP 响应")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "non_http_response"
                )
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
                print("❌ 非 2xx：\(http.statusCode), body=\(body)")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "http_\(http.statusCode)"
                )
                return
            }
            guard let data = data else {
                print("❌ 空数据")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "empty_data"
                )
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantra = parsed["mantra"] as? String {
                    
                    // ✅ Optional per-category reasoning from backend.
                    // Supports your new shape:
                    //   "mapping": { "Place": "...", "Color": "...", ... }
                    // and legacy:
                    //   "reasoning": { ... }
                    func coerceStringDict(_ any: Any?) -> [String: String] {
                        if let dict = any as? [String: String] {
                            return dict
                        }
                        guard let dict = any as? [String: Any] else { return [:] }
                        return dict.reduce(into: [String: String]()) { acc, pair in
                            if let s = pair.value as? String { acc[pair.key] = s }
                        }
                    }

                    print("🧠 FastAPI parsed keys:", parsed.keys.sorted())
                    if let v = parsed["mapping"] { print("🧠 FastAPI mapping type:", String(describing: type(of: v))) }
                    if let v = parsed["reasoning"] { print("🧠 FastAPI reasoning type:", String(describing: type(of: v))) }

                    // Backend may return mapping nested under explanation:
                    // {
                    //   "recommendations": { ... },
                    //   "mantra": "...",
                    //   "explanation": {
                    //      "mapping": { "Place": "...", ... },
                    //      "reasoning_summary": "..."
                    //   }
                    // }
                    let rawReasoning: [String: String] = {
                        if let mappingAny = parsed["mapping"] {
                            return coerceStringDict(mappingAny)
                        }
                        if let explanation = parsed["explanation"] as? [String: Any] {
                            if let mappingAny = explanation["mapping"] {
                                return coerceStringDict(mappingAny)
                            }
                            if let reasoningAny = explanation["reasoning"] as? [String: Any] {
                                if let nested = reasoningAny["mapping"] {
                                    return coerceStringDict(nested)
                                }
                                return coerceStringDict(reasoningAny)
                            }
                        }
                        if let reasoningAny = parsed["reasoning"] as? [String: Any] {
                            if let nested = reasoningAny["mapping"] {
                                return coerceStringDict(nested)
                            }
                            return coerceStringDict(reasoningAny)
                        }
                        if let reasoning = parsed["reasoning"] as? [String: String] {
                            return reasoning
                        }
                        return [:]
                    }()

                    let rawHowToEngage: [String: String] = {
                        if let explanation = parsed["explanation"] as? [String: Any],
                           let engageAny = explanation["how_to_engage"] {
                            return coerceStringDict(engageAny)
                        }
                        if let engageAny = parsed["how_to_engage"] {
                            return coerceStringDict(engageAny)
                        }
                        return [:]
                    }()

                    let normalizedHowToEngage: [String: String] = rawHowToEngage.reduce(into: [:]) { acc, pair in
                        let key = self.canonicalCategory(from: pair.key) ?? pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty else { return }
                        acc[key] = pair.value
                    }

                    let reasoningSummary: String? = {
                        if let s = parsed["reasoning_summary"] as? String { return s }
                        if let explanation = parsed["explanation"] as? [String: Any],
                           let s = explanation["reasoning_summary"] as? String {
                            return s
                        }
                        return nil
                    }()

                    let reasoningSummaryText = reasoningSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let resolvedReasoningSummary = reasoningSummaryText.isEmpty
                        ? "Generated from your current signals."
                        : reasoningSummaryText

                    print("🧠 FastAPI rawReasoning count:", rawReasoning.count, "keys:", rawReasoning.keys.sorted())


                    let reasoning = resolvedReasoningSummary

                    DispatchQueue.main.async {
                        // ✅ 把后端 recommendations 的 key 统一成规范写法
                        let normalized: [String: String] = recs.reduce(into: [:]) { acc, kv in
                            if let canon = canonicalCategory(from: kv.key) {
                                acc[canon] = sanitizeDocumentName(kv.value)
                            }
                        }
                        
                        // ✅ NEW: normalize reasoning keys too (same canon keys as normalized)
                        let normalizedReasoning: [String: String] = rawReasoning.reduce(into: [:]) { acc, kv in
                            if let canon = canonicalCategory(from: kv.key) {
                                acc[canon] = kv.value
                            }
                        }

                        // 更新本地
                        viewModel.recommendations = normalized
                        viewModel.dailyMantra = mantra
                        viewModel.howToEngage = normalizedHowToEngage
                        lastRecommendationDate = today
                        viewModel.reasoningSummary = reasoning
                        cacheCurrentDailyFocusIfPossible(day: today)
                        updateLastRecommendationStampIfReady(mantra: mantra, recs: normalized, isDefault: false)
                        completeGenerationIfNeeded(isDefault: false)

                        // ✅ 先用一个“可用的地点”占位（立即显示），随后用反地理编码精确覆盖
                        let guessedPlace = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !guessedPlace.isEmpty {
                            lastRecommendationPlace = guessedPlace
                        } else if lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            lastRecommendationPlace = "Unknown"
                        }

                        // 先刷新标题（UI 需要）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fetchAllRecommendationTitles()
                        }

                        // 幂等：固定 docId = uid_yyyy-MM-dd，setData(merge:)
                        var recommendationData: [String: Any] = normalized
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = today
                        recommendationData["mantra"] = mantra
                        recommendationData["generatedPlace"] = lastRecommendationPlace// ✅ NEW
                        recommendationData["check_in_inputs"] = [
                            "mood": viewModel.checkInMood ?? "",
                            "stress": viewModel.checkInStress ?? "",
                            "sleep": viewModel.checkInSleep ?? "",
                            "personal_notes": viewModel.checkInNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        ]

                        // ✅ Write reasoning into Firestore only when backend provides it.
                        // Avoid overwriting with placeholders, so missing reasoning is obvious.
                        if !normalizedReasoning.isEmpty {
                            recommendationData["reasoning"] = normalizedReasoning
                            // Also store under "mapping" for forward compatibility with backend naming.
                            recommendationData["mapping"] = normalizedReasoning
                        } else {
                            recommendationData["reasoning"] = FieldValue.delete()
                            recommendationData["mapping"] = FieldValue.delete()
                            print("⚠️ Backend did not provide reasoning/mapping; not writing placeholder reasoning.")
                        }
                        if !normalizedHowToEngage.isEmpty {
                            recommendationData["how_to_engage"] = normalizedHowToEngage
                        } else {
                            recommendationData["how_to_engage"] = FieldValue.delete()
                        }

                        recommendationData["reasoning_summary"] = reasoning


                        // ✅ 如果之前写过默认值，这里要显式“转正”
                        recommendationData["isDefault"] = false
                        recommendationData["fallbackReason"] = FieldValue.delete()
                        recommendationData["updatedAt"] = FieldValue.serverTimestamp()

                        docRef.setData(recommendationData, merge: true) { err in
                            if let err = err {
                                print("❌ 保存 daily_recommendation 失败：\(err)")
                            } else {
                                print("✅ 今日推荐已保存（幂等写入）")
                            }
                        }
                        
                        // Refresh reasoning store for detail sheets
                        if let d = DateFormatter.appDayKey.date(from: today) {
                            self.reasoningStore.load(for: d)
                        } else {
                            self.reasoningStore.load(for: Date())
                        }

                        persistWidgetSnapshotFromViewModel()

                        // ✅ NEW：用本次生成坐标做反地理编码，拿到更准确的 place 后再覆盖写回
                        getAddressFromCoordinate(coord) { place in
                            let resolved = (place ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !resolved.isEmpty else { return }

                            DispatchQueue.main.async {
                                self.lastRecommendationPlace = resolved
                            }

                            docRef.setData(["generatedPlace": resolved], merge: true) { e in
                                if let e = e {
                                    print("⚠️ 写入 generatedPlace 失败：\(e.localizedDescription)")
                                }
                            }
                        }
                    }
                } else {
                    print("❌ FastAPI 返回缺少必要字段（recommendations/mantra）")
                    saveDefaultDailyRecommendationToCalendar(
                        userId: userId,
                        today: today,
                        docRef: docRef,
                        reason: "missing_fields"
                    )
                }
            } catch {
                print("❌ FastAPI 响应解析失败: \(error)")
                print("↳ raw body:", String(data: data, encoding: .utf8) ?? "<binary>")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "parse_error"
                )
            }
        }.resume()
    }

    
    
    
    private func navItemView(title: String, geometry: GeometryProxy, index: Int, cellHeight: CGFloat = 90) -> some View {
        let documentName = viewModel.recommendations[title] ?? ""
        let startCat = RecCategory(rawValue: title) // "Place" -> .Place
        return Group {
            if let startCat, !documentName.isEmpty {
                Button {
                    shouldCollapseMantraOnReturn = true
                    mainNavigationPath.append(startCat)
                } label: {
                    VStack(spacing: 2) {   // ⬅️ tighter spacing
                        // 图标图像
                        SafeImage(name: documentName, renderingMode: .template, contentMode: .fit)
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: geometry.size.width * 0.16)  // slightly smaller to balance text
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 1.5)
                            .scaleEffect(isMantraExpanded ? 0.78 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.82, blendDuration: 0.2), value: isMantraExpanded)
                            .staggered(index, show: $showGridItems, baseDelay: 0.07)
                        
                        // 推荐名称（小字体，紧贴图标）
                        Text(recommendationTitles[title] ?? "")
                            .font(AlignaType.gridItemName())
                            .lineSpacing(AlignaType.body16LineSpacing) // 22-16=6
                            .foregroundColor(themeManager.descriptionText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        
                        // 类别标题（和上面稍微拉开）
                        Text(categoryDisplayName(for: title))
                            .font(AlignaType.gridCategoryTitle())
                            .lineSpacing(34 - 28) // 6
                            .foregroundColor(themeManager.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(themeManager.panelFill.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(themeManager.panelStrokeHi.opacity(0.6), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didDeleteAccount)) { _ in
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            isLoggedIn = false
            authWaitTimedOut = true
            if let h = authListenerHandle {
                Auth.auth().removeStateDidChangeListener(h)
                authListenerHandle = nil
            }
            withAnimation(.easeInOut) { bootPhase = .onboarding }
        }
        .onChange(of: bootPhase, initial: false) { _, phase in
            handleBootPhaseChange(phase)
        }
        /*
        // Removed applyBootPhaseChangeHandler and replaced with inline onChange above
        */
    }
    private func handleBootPhaseChange(_ phase: BootPhase) {
        if phase == .main {
            isMantraExpanded = true
            if shouldExpandMantraOnBoot {
                shouldExpandMantraOnBoot = false
            }
            if pendingGenerationToast {
                pendingGenerationToast = false
                triggerGenerationHapticIfNeeded()
                showCenterToast("Updated for today", duration: 2.2, includeTime: false)
            }
            if showGenerationStrongHint && isGenerationInProgress {
                showCenterToast("Generating today’s mantra and rhythm", duration: 2.6, includeTime: false)
            }
        }
    }

    private func makeDocsMap() -> [RecCategory: String] {
        Dictionary(uniqueKeysWithValues: RecCategory.allCases.map { cat in
            let key = cat.rawValue
            return (cat, viewModel.recommendations[key] ?? "")
        })
    }

    /*
    @ViewBuilder
    private func applyBootPhaseChangeHandler() -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: bootPhase, initial: false) { _, phase in
                handleBootPhaseChange(phase)
            }
        } else {
            self.onChange(of: bootPhase) { phase in
                handleBootPhaseChange(phase)
            }
        }
    }
    */
    // REMOVED applyBootPhaseChangeHandler() as per instructions

    @ViewBuilder
    private func viewForCategory(title: String, documentName: String) -> some View {
        switch title {
        case "Place":
            PlaceDetailView(documentName: documentName)
        case "Gemstone":
            GemstoneDetailView(documentName: documentName)
        case "Color":
            ColorDetailView(documentName: documentName)
        case "Scent":
            ScentDetailView(documentName: documentName)
        case "Activity":
                    ActivityDetailView(
                        documentName: documentName
        //                soundDocumentName: viewModel.recommendations["Sound"] ?? ""
                    )
        case "Sound":
            SoundDetailView(documentName: documentName)
        case "Career":
            CareerDetailView(documentName: documentName)
        case "Relationship":
            RelationshipDetailView(documentName: documentName)
        default:
            Text("⚠️ Unknown Category")
        }
    }
    
    
    private func loadTodayRecommendation(
        day: String? = nil,
        source: FirestoreSource = .default,
        allowRemoteFallback: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法获取推荐")
            completion?()
            return
        }

        let today = day ?? todayString()
        let db = Firestore.firestore()
        let fixedDocRef = todayDocRef(uid: userId, day: today)

        func finish() {
            DispatchQueue.main.async {
                completion?()
            }
        }

        func applyDailyData(_ data: [String: Any]) {
            var recs: [String: String] = [:]
            var fetchedMantra = ""
            var fetchedReasoning = ""
            var reasoningMap: [String: String] = [:]
            var fetchedHowToEngage: [String: String] = [:]
            var fetchedMood: String? = nil
            var fetchedStress: String? = nil
            var fetchedSleep: String? = nil
            var fetchedNotes = ""

            let fetchedPlace = (data["generatedPlace"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isDefault = (data["isDefault"] as? Bool) == true

            if let rawReasoning = data["reasoning"] as? [String: Any] {
                for (key, value) in rawReasoning {
                    if let s = value as? String {
                        reasoningMap[key] = s
                    }
                }
            } else if let rawReasoning = data["mapping"] as? [String: Any] {
                for (key, value) in rawReasoning {
                    if let s = value as? String {
                        reasoningMap[key] = s
                    }
                }
            }

            if let rawHowToEngage = data["how_to_engage"] as? [String: Any] {
                for (key, value) in rawHowToEngage {
                    guard let s = value as? String else { continue }
                    let resolvedKey = canonicalCategory(from: key) ?? key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !resolvedKey.isEmpty else { continue }
                    fetchedHowToEngage[resolvedKey] = s
                }
            }

            if let rawCheckIn = data["check_in_inputs"] as? [String: Any] {
                func nonEmptyText(_ key: String) -> String? {
                    let raw = rawCheckIn[key] as? String ?? ""
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }

                fetchedMood = nonEmptyText("mood")
                fetchedStress = nonEmptyText("stress")
                fetchedSleep = nonEmptyText("sleep")
                fetchedNotes = nonEmptyText("personal_notes") ?? ""
            }

            for (key, value) in data {

                // ✅ mantra：你之前漏了这段，导致第二次打开时被覆盖为空
                if key == "mantra", let s = value as? String {
                    fetchedMantra = s
                    continue
                }

                // ✅ reasoning summary：支持两种 key
                if (key == "reasoning_summary" || key == "reasoningSummary"),
                   let s = value as? String {
                    fetchedReasoning = s
                    continue
                }

                // ✅ 跳过元数据字段
                if key == "uid"
                    || key == "createdAt"
                    || key == "updatedAt"
                    || key == "isDefault"
                    || key == "fallbackReason"
                    || key == "generatedPlace"
                    || key == "mantra"
                    || key == "reasoning_summary"
                    || key == "reasoningSummary" {
                    continue
                }

                // ✅ 推荐类别字段（大小写无关→规范写法）
                if let canon = canonicalCategory(from: key), let str = value as? String {
                    recs[canon] = sanitizeDocumentName(str)
                }
            }

            DispatchQueue.main.async {
                self.lastRecommendationDate = today

                if !fetchedPlace.isEmpty {
                    self.lastRecommendationPlace = fetchedPlace
                }

                self.viewModel.recommendations = recs
                self.viewModel.howToEngage = fetchedHowToEngage
                self.viewModel.checkInMood = fetchedMood
                self.viewModel.checkInStress = fetchedStress
                self.viewModel.checkInSleep = fetchedSleep
                self.viewModel.checkInNotes = fetchedNotes

                // ✅ 只有在 Firestore 真有 mantra 时才覆盖；避免把已有 UI 文本刷成空
                let mantraTrim = fetchedMantra.trimmingCharacters(in: .whitespacesAndNewlines)
                if !mantraTrim.isEmpty {
                    self.viewModel.dailyMantra = fetchedMantra
                } else {
                    // 诊断日志：帮助你确认 Firestore 是否写入了 mantra
                    print("⚠️ Firestore 今日文档没有 mantra 或为空（docId=\(userId)_\(today)）")
                }

                let resolvedMantra = mantraTrim.isEmpty ? self.viewModel.dailyMantra : fetchedMantra
                self.isDefaultRecommendation = isDefault
                self.cacheCurrentDailyFocusIfPossible(day: today)
                self.updateLastRecommendationStampIfReady(mantra: resolvedMantra, recs: recs, isDefault: isDefault)
                self.completeGenerationIfNeeded(isDefault: isDefault)

                if isDefault {
                    print("⚠️ 今日文档仍是默认推荐（docId=\(userId)_\(today)），继续触发重拉")
                    forceRefetchDailyIfNotLocked()
                }

                let reasoningTrim = fetchedReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !reasoningTrim.isEmpty else {
                    print("⚠️ Firestore 今日文档没有 reasoning_summary 或为空（docId=\(userId)_\(today)），触发重拉")
                    forceRefetchDailyIfNotLocked()
                    finish()
                    return
                }
                self.viewModel.reasoningSummary = fetchedReasoning

                self.ensureDefaultsIfMissing()
                self.fetchAllRecommendationTitles()
                self.persistWidgetSnapshotFromViewModel()
                self.markMantraReadyIfPossible()

                print("✅ 成功加载今日推荐（固定 docId 优先）：\(recs), mantra=\(!mantraTrim.isEmpty), reasoning=\(!reasoningTrim.isEmpty), place=\(fetchedPlace)")
                finish()
            }
        }

        // 1) ✅ 优先读取固定 docId：uid_yyyy-MM-dd
        fixedDocRef.getDocument(source: source) { snap, err in
            if let err = err {
                if source == .cache && allowRemoteFallback {
                    loadTodayRecommendation(day: today, source: .default, allowRemoteFallback: true, completion: completion)
                    return
                }
                print("❌ 读取今日固定 docId 失败：\(err.localizedDescription)；使用本地默认内容")
                DispatchQueue.main.async {
                    self.ensureDefaultsIfMissing()
                    finish()
                }
                return
            }

            if let snap = snap, snap.exists, let data = snap.data() {
                applyDailyData(data)
                return
            }

            if source == .cache && allowRemoteFallback {
                loadTodayRecommendation(day: today, source: .default, allowRemoteFallback: true, completion: completion)
                return
            }

            guard allowRemoteFallback else {
                DispatchQueue.main.async {
                    self.ensureDefaultsIfMissing()
                    finish()
                }
                return
            }

            // 2) 兼容旧数据：回退查询随机 docId 文档
            db.collection("daily_recommendation")
                .whereField("uid", isEqualTo: userId)
                .whereField("createdAt", isEqualTo: today)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ 回退查询今日推荐失败：\(error). 使用本地默认内容")
                        DispatchQueue.main.async {
                            self.ensureDefaultsIfMissing()
                            finish()
                        }
                        return
                    }

                    guard let docs = snapshot?.documents, !docs.isEmpty else {
                        print("⚠️ 今日暂无推荐数据。使用本地默认内容")
                        DispatchQueue.main.async {
                            self.ensureDefaultsIfMissing()
                            finish()
                        }
                        return
                    }

                    let best = docs.max { a, b in
                        let ta = (a.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                        let tb = (b.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                        return ta < tb
                    } ?? docs[0]

                    let data = best.data()
                    applyDailyData(data)

                    // 3) ✅ 迁移写回固定 docId
                    var migrated = data
                    migrated["uid"] = userId
                    migrated["createdAt"] = today
                    migrated["updatedAt"] = FieldValue.serverTimestamp()

                    fixedDocRef.setData(migrated, merge: true) { e in
                        if let e = e {
                            print("⚠️ 迁移写入固定 docId 失败：\(e.localizedDescription)")
                        } else {
                            print("✅ 已迁移今日推荐到固定 docId（避免返回首页随机命中旧文档）")
                        }
                    }
                }
        }
    }
    
    private func debugAndRefreshReasoningSummaryFromFirestore(day: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ debugReasoning: 未登录")
            return
        }

        let today = day ?? todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        docRef.getDocument { snap, err in
            if let err = err {
                print("❌ debugReasoning: 读取 docId=\(uid)_\(today) 失败：\(err.localizedDescription)")
                return
            }

            guard let snap = snap, snap.exists, let data = snap.data() else {
                print("⚠️ debugReasoning: 今日文档不存在（docId=\(uid)_\(today)）")
                return
            }

            // ✅ 打印全部 keys，帮你确认到底写进去了什么字段
            let keys = data.keys.sorted()
            print("🔎 debugReasoning: keys = \(keys)")

            // ✅ 尝试读取两种 key
            let r1 = (data["reasoning_summary"] as? String) ?? ""
            let r2 = (data["reasoningSummary"] as? String) ?? ""
            let reasoning = [r1, r2]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? ""

            if reasoning.isEmpty {
                print("⚠️ debugReasoning: reasoning 为空。reasoning_summary=\(r1.count) chars, reasoningSummary=\(r2.count) chars")
            } else {
                print("✅ debugReasoning: 拿到 reasoning，长度=\(reasoning.count)")
                DispatchQueue.main.async {
                    self.viewModel.reasoningSummary = reasoning
                }
            }
        }
    }





    // === Case-insensitive category normalization ===
    // 后端可能返回 "color" / "Color" / "COLOR"；统一映射到规范写法
    private let categoryCanonicalMap: [String: String] = [
        "place": "Place",
        "gemstone": "Gemstone",
        "color": "Color",
        "scent": "Scent",
        "activity": "Activity",
        "sound": "Sound",
        "career": "Career",
        "relationship": "Relationship"
    ]

    private func canonicalCategory(from raw: String) -> String? {
        categoryCanonicalMap[raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    // ✅ 仅允许的类别白名单
    private let allowedCategories: Set<String> = [
        "Place", "Gemstone", "Color", "Scent",
        "Activity", "Sound", "Career", "Relationship"
    ]

    // ✅ 类别 -> 集合名 映射函数（返回可选，未知类别返回 nil）
    private func firebaseCollectionName(for rawCategory: String) -> String? {
        let category = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        switch category {
        case "Place":        return "places"
        case "Gemstone":     return "gemstones"
        case "Color":        return "colors"
        case "Scent":        return "scents"
        case "Activity":     return "activities"
        case "Sound":        return "sounds"
        case "Career":       return "careers"
        case "Relationship": return "relationships"
        default:
            return nil
        }
    }

    // ✅ 文档名清洗：移除会破坏路径的字符（如 /、\、# 等）
    //   Firestore 文档 ID 不允许包含斜杠；这里最小清洗，保留字母数字下划线与连字符。
    private func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Reasoning Bubble UI

struct ReasoningBubbleView: View {
    let text: String
    let textColor: Color
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(text)
                    .font(.custom("Merriweather-Regular", size: 14))
                    .foregroundColor(textColor)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 10)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            SpeechBubbleShape(tailWidth: 18, tailHeight: 10, tailOffsetX: 0)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            SpeechBubbleShape(tailWidth: 18, tailHeight: 10, tailOffsetX: 0)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
        .accessibilityLabel("Reasoning summary bubble")
    }
}

struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 10
    /// tailOffsetX: 0 means centered; negative moves left, positive moves right
    var tailOffsetX: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Bubble rect is lowered to make room for the tail on top
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )

        // Rounded rect
        p.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Tail (top-middle)
        let centerX = rect.midX + tailOffsetX
        let tailHalf = tailWidth / 2

        let a = CGPoint(x: centerX - tailHalf, y: bubbleRect.minY)
        let b = CGPoint(x: centerX, y: rect.minY)
        let c = CGPoint(x: centerX + tailHalf, y: bubbleRect.minY)

        p.move(to: a)
        p.addLine(to: b)
        p.addLine(to: c)
        p.closeSubpath()

        return p
    }
}



enum DesignRecs {
    static let docs: [String:String] = [
        "Place": "echo_niche",
        "Gemstone": "amethyst",
        "Color": "amber",
        "Scent": "bergamot",
        "Activity": "clean_mirror",
        "Sound": "brown_noise",
        "Career": "clear_channel",
        "Relationship": "breathe_sync"
    ]
    static let titles: [String:String] = [
        "Place": "Echo Niche", "Gemstone": "Amethyst", "Color": "Amber",
        "Scent": "Bergamot", "Activity": "Polishing Mirror",
        "Sound": "Brown Noise", "Career": "Clear Channel",
        "Relationship": "Breathe in Sync"
    ]
    static let mantra = "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."
}


#if DEBUG
extension MainView {
    init(previewBoot: BootPhase) {
        self.init()
        _bootPhase = State(initialValue: previewBoot) // jump straight to .main
    }
}
#endif

#if DEBUG
private struct FirstPagePreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    @StateObject private var viewModel: OnboardingViewModel
    @StateObject private var reasoningStore = DailyReasoningStore()
    @StateObject private var soundPlayer = SoundPlayer.shared

    init() {
        let themeManager = ThemeManager()
        themeManager.selected = .day
        _themeManager = StateObject(wrappedValue: themeManager)

        let viewModel = OnboardingViewModel()
        viewModel.recommendations = [
            "Place": "echo_niche",
            "Gemstone": "amethyst",
            "Color": "amber",
            "Scent": "bergamot",
            "Activity": "clean_mirror",
            "Sound": "brown_noise",
            "Career": "clear_channel",
            "Relationship": "breathe_sync"
        ]
        viewModel.dailyMantra = "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        MainView(previewBoot: .main)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .environmentObject(viewModel)
            .environmentObject(soundPlayer)
            .environmentObject(reasoningStore)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Main View") {
    FirstPagePreviewContainer()
}
#endif

#if DEBUG
let _isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#endif


enum RecCategory: String, CaseIterable, Identifiable {
    case Place, Gemstone, Color, Scent, Activity, Sound, Career, Relationship
    var id: String { rawValue }
}

struct RecommendationPagerView: View {
    let docsByCategory: [RecCategory: String]
    let selected: RecCategory
    let onBack: () -> Void

    @State private var selectedIndex: Int = 1

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var categories: [RecCategory] { RecCategory.allCases }
    private var loopedCategories: [RecCategory] {
        guard let first = categories.first, let last = categories.last else { return [] }
        return [last] + categories + [first]
    }

    var body: some View {
        ZStack {
            // Full-bleed background
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .ignoresSafeArea() // <- key line

            TabView(selection: $selectedIndex) {
                ForEach(loopedCategories.indices, id: \.self) { idx in
                    let cat = loopedCategories[idx]
                    Group {
                        if let doc = docsByCategory[cat], !doc.isEmpty {
                            pageView(for: cat, documentName: doc).id(doc)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading \(cat.rawValue)…")
                                    .foregroundColor(themeManager.descriptionText.opacity(0.7))
                            }
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .onAppear {
                if let start = categories.firstIndex(of: selected) {
                    selectedIndex = start + 1
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                let lastIndex = loopedCategories.count - 1
                if newValue == 0 {
                    withAnimation(.none) { selectedIndex = lastIndex - 1 }
                } else if newValue == lastIndex {
                    withAnimation(.none) { selectedIndex = 1 }
                }
            }

            CustomBackButton(
                //                iconSize: 18,
                ////                paddingSize: 8,
                //                backgroundColor: Color.black.opacity(0.3),
                //                iconColor: themeManager.primaryText,
                ////                topPadding: 120,
                //                horizontalPadding: 24
                action: {
                    onBack()
                    dismiss()          // pop back to MainView
                }
            )
        }
        // Prevent the default nav bar blur from showing at the top
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar) // if you don’t want any bar at all
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
    
    @ViewBuilder
    private func pageView(for cat: RecCategory, documentName: String) -> some View {
        switch cat {
        case .Place:
            PlaceDetailView(documentName: documentName)
        case .Gemstone:
            GemstoneDetailView(documentName: documentName)
        case .Color:
            ColorDetailView(documentName: documentName)
        case .Scent:
            ScentDetailView(documentName: documentName)
        case .Activity:
            ActivityDetailView(documentName: documentName)
//                               soundDocumentName: docsByCategory[.Sound] ?? "")
        case .Sound:
            SoundDetailView(documentName: documentName)
        case .Career:
            CareerDetailView(documentName: documentName)
        case .Relationship:
            RelationshipDetailView(documentName: documentName)
        }
    }
}







// Back button

struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    // Match the Account Detail look (clean icon, no circle)
    var iconSize: CGFloat = 26
    var topPadding: CGFloat = 20
    var horizontalPadding: CGFloat = 20
    var showsBackground: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { action?() ?? dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(themeManager.primaryText)
                        .padding(showsBackground ? 12 : 0)
                        .background(showsBackground ? Color.white.opacity(0.10) : Color.clear)
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
            Spacer()
        }
    }
}


#if DEBUG
#Preview("Main Expanded") {
    let defaults = UserDefaults.standard
    defaults.set(Date().timeIntervalSince1970 - 3600, forKey: "lastRecommendationTimestamp")
    defaults.set(true, forKey: "lastRecommendationHasFullSet")

    let starManager = StarAnimationManager()
    let themeManager = ThemeManager()
    let viewModel = OnboardingViewModel()
    viewModel.dailyMantra = "Take a steady breath and follow the quiet momentum."
    viewModel.recommendations = DesignRecs.docs

    let soundPlayer = SoundPlayer()
    let reasoningStore = DailyReasoningStore()

    return MainView(
        previewExpanded: true,
        previewShowGeneration: true,
        previewToastMessage: "Updated",
        previewShowStrongHint: false,
        previewUsingPreviousResult: true
    )
    .environmentObject(starManager)
    .environmentObject(themeManager)
    .environmentObject(viewModel)
    .environmentObject(soundPlayer)
    .environmentObject(reasoningStore)
}
#endif

// 替换你文件中现有的 OnboardingViewModel
import FirebaseFirestore
import FirebaseAuth
import MapKit
