import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit

class OnboardingViewModel: ObservableObject {
    @Published var userId: String = ""
    @Published var nickname: String = ""
    @Published var gender: String = ""
    @Published var relationshipStatus: String = ""
    @Published var birth_date: Date = Date()
    @Published var birth_time: Date = Date()
    @Published var birthPlace: String = ""
    @Published var birthTimezoneOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60
    @Published var currentPlace: String = ""
    @Published var birthCoordinate: CLLocationCoordinate2D?
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var recommendations: [String: String] = [:]
    @Published var dailyMantra: String = ""
    @Published var reasoningSummary: String = ""

    
    // ✅ 新增：Step3 的五个答案
    @Published var scent_dislike: Set<String> = []     // 多选
    @Published var act_prefer: Set<String> = []        // 多选
    @Published var color_dislike: Set<String> = []     // 多选
    @Published var allergies: Set<String> = []         // 多选
    @Published var music_dislike: Set<String> = []     // 多选

    // Place signals — populated by LoadingView from the Open-Meteo weather fetch.
    // Optional; nil means data was unavailable when the loading screen ran.
    @Published var weatherCondition: String? = nil
    @Published var temperature: Double? = nil     // °F
    @Published var windDirection: String? = nil   // compass string, e.g. "NW"
    @Published var windSpeed: Double? = nil       // mph
    @Published var humidity: Double? = nil        // 0–100 %
    @Published var pressure: Double? = nil        // hPa
    @Published var airQualityAQI: Double? = nil
    @Published var airQualityPM25: Double? = nil
    @Published var waterPercent: Double? = nil
    @Published var greenPercent: Double? = nil
    @Published var builtPercent: Double? = nil
    @Published var geomagneticDeclinationDeg: Double? = nil
    @Published var geomagneticDeclinationSvDegPerYear: Double? = nil
    @Published var geomagneticDeclinationUncertaintyDeg: Double? = nil
    @Published var geomagneticElevationKm: Double? = nil
}




import SwiftUI
// 统一进场动画修饰器：按 index 级联
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Binding var show: Bool
    var baseDelay: Double = 0.08
    
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 16)
            .scaleEffect(show ? 1 : 0.985)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.2)
                    .delay(baseDelay * Double(index)),
                value: show
            )
    }
}

extension View {
    func staggered(_ index: Int, show: Binding<Bool>, baseDelay: Double = 0.08) -> some View {
        self.modifier(StaggeredAppear(index: index, show: show, baseDelay: baseDelay))
    }
}

// MARK: - Aligna 标题（逐字母入场）
struct AlignaHeading: View {
    // 保持你原来的入参不变，兼容现有调用
    let textColor: Color
    @Binding var show: Bool

    // 新增可调参数（有默认值，不会破坏现有调用）
    var text: String = "Alynna"
    var fontSize: CGFloat = 34
    var perLetterDelay: Double = 0.07   // 每个字母的出现间隔
    var duration: Double = 0.26         // 单个字母动画时长
    var letterSpacing: CGFloat = 0      // 需要更“松”的字距，可以传入 > 0

    var body: some View {
        let letters = Array(text)
        HStack(spacing: letterSpacing) {
            ForEach(letters.indices, id: \.self) { i in
                Text(String(letters[i]))
                    .font(Font.custom("Merriweather-Bold", size: fontSize))
                    .foregroundColor(textColor)
                    .opacity(show ? 1 : 0)
                    .offset(y: show ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration).delay(perLetterDelay * Double(i)),
                        value: show
                    )
            }
        }
        .accessibilityLabel(text)
    }
}


// MARK: - Staggered Letters (逐字母入场)
struct StaggeredLetters: View {
    let text: String
    let font: Font
    let color: Color
    let letterSpacing: CGFloat
    let duration: Double       // 单个字母的动画时长
    let perLetterDelay: Double // 每个字母之间的间隔

    @State private var active = false

    var body: some View {
        HStack(spacing: letterSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, ch in
                Text(String(ch))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration)
                            .delay(perLetterDelay * Double(idx)),
                        value: active
                    )
            }
        }
        .onAppear { active = true }
    }
}





final class AppleAuthManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var completion: ((Result<ASAuthorization, Error>) -> Void)?

    func startSignUp(nonce: String, completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        // 你的项目里已有 sha256(nonce)，直接用
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎 [Apple] didCompleteWithAuthorization")
        completion?(.success(authorization))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🍎 [Apple] didCompleteWithError: \(error.localizedDescription)")
        completion?(.failure(error))
        completion = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 取当前 key window
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        return window
    }
}


extension View {
    func hideKeyboardOnTapOutside<T: Hashable>(_ focus: FocusState<T?>.Binding) -> some View {
        self
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded { focus.wrappedValue = nil }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { _ in
                    focus.wrappedValue = nil
                }
            )
    }
}


import SwiftUI
import MapKit

struct AlignaTopHeader: View {
    @EnvironmentObject var themeManager: ThemeManager

    let minLength: CGFloat
    var show: Binding<Bool>? = nil

    @State private var localShow = false

    private var activeShow: Binding<Bool> {
        show ?? $localShow
    }

    var body: some View {
        VStack(spacing: minLength * 0.02) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: minLength * 0.14)
                    .foregroundColor(themeManager.onboardingPrimaryText.opacity(0.92))
            } else {
                Image(systemName: "leaf.circle.fill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: minLength * 0.14)
                    .foregroundColor(themeManager.onboardingPrimaryText.opacity(0.92))
            }

            AlignaHeading(
                textColor: themeManager.onboardingPrimaryText,
                show: activeShow,
                fontSize: minLength * 0.12,
                letterSpacing: minLength * 0.005
            )
        }
        .onAppear {
            guard show == nil else { return }
            localShow = true
        }
    }
}

private struct OnboardingBackOverlay: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(themeManager.onboardingPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
        }
    }
}
private struct OnboardingTitleStyle: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .font(.custom("Merriweather-Bold", size: 20))
            .foregroundColor(themeManager.onboardingPrimaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

private struct OnboardingQuestionStyle: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .font(.custom("Merriweather-Bold", size: 16))
            .foregroundColor(themeManager.onboardingPrimaryText.opacity(0.92))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

private struct OnboardingCaptionStyle: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .font(.custom("Merriweather-Regular", size: 13))
            .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.85))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

private let onboardingPrivacyNote = "We securely save your gender, relationship status, birth date, and birth time only to calculate your zodiac and birth chart details."

private struct OnboardingPrimaryButtonStyle: ViewModifier {
    let isEnabled: Bool
    @EnvironmentObject var themeManager: ThemeManager

    private var buttonBackground: Color {
        isEnabled ? themeManager.onboardingPrimaryText : themeManager.onboardingPrimaryText.opacity(0.4)
    }

    private var buttonForeground: Color {
        themeManager.isNight ? .black : .white
    }

    func body(content: Content) -> some View {
        content
            .font(AlynnaTypography.font(.headline).weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(buttonBackground)
            .foregroundColor(isEnabled ? buttonForeground : buttonForeground.opacity(0.65))
            .cornerRadius(14)
    }
}

private struct OnboardingLabelStyle: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .font(.custom("Merriweather-Regular", size: 13))
            .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.85))
    }
}

extension ThemeManager {
    var onboardingPrimaryText: Color {
        isNight ? fixedNightTextPrimary : primaryText
    }

    var onboardingSecondaryText: Color {
        isNight ? fixedNightTextSecondary : descriptionText
    }

    var onboardingTertiaryText: Color {
        isNight ? fixedNightTextTertiary : descriptionText.opacity(0.85)
    }

    var onboardingPanelFill: Color {
        onboardingSecondaryText.opacity(isNight ? 0.14 : 0.10)
    }

    var onboardingPanelStroke: Color {
        onboardingSecondaryText.opacity(isNight ? 0.35 : 0.25)
    }
}

extension Text {
    func onboardingTitleStyle() -> some View {
        modifier(OnboardingTitleStyle())
    }

    func onboardingQuestionStyle() -> some View {
        modifier(OnboardingQuestionStyle())
    }

    func onboardingCaptionStyle() -> some View {
        modifier(OnboardingCaptionStyle())
    }

    func onboardingPrimaryButtonStyle(isEnabled: Bool = true) -> some View {
        modifier(OnboardingPrimaryButtonStyle(isEnabled: isEnabled))
    }

    func onboardingLabelStyle() -> some View {
        modifier(OnboardingLabelStyle())
    }
}




import SwiftUI
import MapKit

struct OnboardingStep0: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @State private var showIntro = false
    private var panelBG: Color { themeManager.onboardingPanelFill }
    private var stroke: Color { themeManager.onboardingPanelStroke }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        AlignaTopHeader(minLength: minLength, show: $showIntro)
                            .staggered(0, show: $showIntro)

                        Text("Your Daily Rhythm")
                            .onboardingTitleStyle()
                            .padding(.top, 6)
                            .staggered(1, show: $showIntro)

                        Text("A personal guide shaped by Earth, sky, and body signals, tuned to each day and your current context.")
                            .onboardingCaptionStyle()
                            .padding(.horizontal, 28)
                            .staggered(2, show: $showIntro)

                        VStack(spacing: 12) {
                            FeatureRow(symbol: "sparkles", text: "Daily recommendations across eight life domains, refreshed each day.")
                            FeatureRow(symbol: "location.north.line", text: "Personalized to your time, place, and physiology, not a generic profile.")
                            FeatureRow(symbol: "heart.circle", text: "Built to support clarity, balance, and follow-through, without overload.")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .background(panelBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(stroke, lineWidth: 1)
                        )
                        .cornerRadius(16)
                        .padding(.horizontal, 26)
                        .staggered(3, show: $showIntro)

                        NavigationLink(
                            destination: OnboardingStep1(viewModel: viewModel)
                                .environmentObject(themeManager)
                                .environmentObject(starManager)
                        ) {
                            Text("Continue")
                                .onboardingPrimaryButtonStyle()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                        .staggered(4, show: $showIntro)
                    }
                }
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top + 8)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: max(12, geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(false)
                }
                OnboardingBackOverlay()
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showIntro = true
                }
            }
        }
    }

    private struct FeatureRow: View {
        @EnvironmentObject var themeManager: ThemeManager

        let symbol: String
        let text: String

        var body: some View {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.accent)
                    .frame(width: 20)

                Text(text)
                    .onboardingLabelStyle()
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
        }
    }
}

struct OnboardingStep1: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    
    @State private var goOpening = false

    private var panelBG: Color { themeManager.onboardingPanelFill }
    private var stroke: Color { themeManager.onboardingPanelStroke }

    // 出生地搜索
    @State private var birthSearch = ""
    @State private var birthResults: [PlaceResult] = []
    @State private var didSelectBirth = false

    // 🔹 焦点控制
    @FocusState private var step1Focus: Step1Field?
    private enum Step1Field { case nickname, birth }

    // 若你也想给 Step1 做入场级联动画，可以用 showIntro；这里只保留结构
    @State private var showIntro = true

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        // 顶部
                        AlignaTopHeader(minLength: minLength)

                        Text("Tell us about yourself")
                            .onboardingTitleStyle()
                            .padding(.top, 6)

                        // 基础信息
                        Group {
                            // Nickname
                            VStack(alignment: .center, spacing: 10) {
                                Text("Your Nickname")
                                    .onboardingQuestionStyle()

                                Group {
                                    TextField("Enter your nickname", text: $viewModel.nickname)
                                        .padding()
                                        .background(panelBG)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(stroke, lineWidth: 1)
                                        )
                                        .cornerRadius(12)
                                        .foregroundColor(themeManager.onboardingPrimaryText)
                                        .focused($step1Focus, equals: .nickname)
                                        .focusGlow(active: step1Focus == .nickname,
                                                   color: .white,
                                                   lineWidth: 2,
                                                   cornerRadius: 12)
                                }
                                .animation(nil, value: step1Focus)
                            }

                            // Gender
                            VStack(alignment: .center, spacing: 10) {
                                Text("Gender")
                                    .onboardingQuestionStyle()

                                HStack(spacing: 10) {
                                    ForEach(["Male", "Female", "Other"], id: \.self) { gender in
                                        Button {
                                            viewModel.gender = gender
                                        } label: {
                                            let selected = viewModel.gender == gender
                                            Text(gender)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(selected ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.18 : 0.14) : panelBG)
                                                .foregroundColor(selected ? themeManager.onboardingPrimaryText : themeManager.onboardingSecondaryText)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(selected ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.55 : 0.35) : stroke, lineWidth: 1)
                                                )
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }

                            // Relationship
                            VStack(alignment: .center, spacing: 10) {
                                Text("Status")
                                    .onboardingQuestionStyle()

                                GeometryReader { geo in
                                    let total = geo.size.width
                                    let spacing: CGFloat = 10
                                    let available = total - spacing * 2
                                    let sideW = available * 0.25
                                    let midW = available - sideW * 2

                                    HStack(spacing: spacing) {
                                        statusButton("Single")
                                            .frame(width: sideW)

                                        statusButton("In a relationship")
                                            .frame(width: midW)

                                        statusButton("Other")
                                            .frame(width: sideW)
                                    }
                                }
                                .frame(height: 52)
                            }

                        }
                        .padding(.horizontal)

                        // 出生地
                        VStack(alignment: .center, spacing: 12) {
                            Text("Place of Birth")
                                .onboardingQuestionStyle()

                            Group {
                                TextField("Your Birth Place", text: $birthSearch)
                                    .padding()
                                    .background(panelBG)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(stroke, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                    .foregroundColor(themeManager.onboardingPrimaryText)
                                    .focused($step1Focus, equals: .birth)
                                    .focusGlow(active: step1Focus == .birth,
                                               color: .white,
                                               lineWidth: 2,
                                               cornerRadius: 12)
                                    .onChange(of: birthSearch) { _, newVal in
                                        if !didSelectBirth && !newVal.isEmpty {
                                            performBirthSearch(query: newVal)
                                        }
                                        didSelectBirth = false
                                    }
                            }
                            .animation(nil, value: step1Focus)

                            if !viewModel.birthPlace.isEmpty {
                                Text("✓ Selected: \(viewModel.birthPlace)")
                                    .onboardingLabelStyle()
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            VStack(spacing: 8) {
                                ForEach(birthResults) { result in
                                    Button {
                                        viewModel.birthPlace = result.name
                                        viewModel.birthCoordinate = result.coordinate
                                        birthSearch = result.name
                                        birthResults = []
                                        didSelectBirth = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.name)
                                                .font(.custom("Merriweather-Bold", size: 15))
                                                .foregroundColor(themeManager.onboardingPrimaryText)
                                            Text(result.subtitle)
                                                .font(.custom("Merriweather-Regular", size: 12))
                                                .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.9))
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(panelBG)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(stroke, lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        Text(onboardingPrivacyNote)
                            .onboardingCaptionStyle()
                            .padding(.horizontal, 28)
                            .padding(.top, 2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Continue
                        NavigationLink(
                            destination: OnboardingStep2(viewModel: viewModel)
                                .environmentObject(themeManager)
                        ) {
                            Text("Continue")
                                .onboardingPrimaryButtonStyle(isEnabled: isFormComplete)
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)
                        .disabled(!isFormComplete)
                        .padding(.bottom, 24)
                    }
                }
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top + 8)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: max(12, geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(false)
                }
                OnboardingBackOverlay()
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { }
        }
    }

    private var isFormComplete: Bool {
        !viewModel.nickname.isEmpty &&
        !viewModel.gender.isEmpty &&
        !viewModel.relationshipStatus.isEmpty &&
        !viewModel.birthPlace.isEmpty
    }

    @ViewBuilder
    private func statusButton(_ status: String) -> some View {
        Button {
            viewModel.relationshipStatus = status
        } label: {
            Text(status)
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, 10)
        .background(viewModel.relationshipStatus == status ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.18 : 0.14) : panelBG)
        .foregroundColor(viewModel.relationshipStatus == status ? themeManager.onboardingPrimaryText : themeManager.onboardingSecondaryText)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(viewModel.relationshipStatus == status ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.55 : 0.35) : stroke, lineWidth: 1)
        )
        .cornerRadius(10)
    }
    

    private func performBirthSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        MKLocalSearch(request: request).start { response, _ in
            guard let items = response?.mapItems else { return }
            let results = items.compactMap { item in
                PlaceResult(
                    name: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
            DispatchQueue.main.async { self.birthResults = results }
        }
    }
}

// MARK: - OnboardingStep2（顶部与 Step1 一致 + 时间保存改为本地锚定）
struct OnboardingStep2: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    // 弹窗控制
    @State private var showDatePickerSheet = false
    @State private var showTimePickerSheet = false

    // 临时选择值（用于滚轮，不直接写回 VM）
    @State private var tempBirthDate: Date = Date()
    @State private var tempBirthTime: Date = Date()

    private var panelBG: Color { themeManager.onboardingPanelFill }
    private var stroke: Color { themeManager.onboardingPanelStroke }

    // 生日范围（1900 ~ 今天）
    private var dateRange: ClosedRange<Date> {
        var comps = DateComponents()
        comps.year = 1900; comps.month = 1; comps.day = 1
        let calendar = Calendar.current
        let start = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
        let end = Date()
        return start...end
    }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        AlignaTopHeader(minLength: minLength)

                        Text("When were you born?")
                            .onboardingTitleStyle()
                            .padding(.top, 6)

                        VStack(spacing: 15) {
                            Text("Birthday")
                                .onboardingQuestionStyle()

                            Button {
                                tempBirthDate = viewModel.birth_date
                                showDatePickerSheet = true
                            } label: {
                                HStack {
                                    Text(viewModel.birth_date.formatted(.dateTime.year().month(.wide).day()))
                                        .foregroundColor(themeManager.onboardingPrimaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.9))
                                }
                                .padding()
                                .background(panelBG)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        VStack(spacing: 15) {
                            Text("Time of Your Birth")
                                .onboardingQuestionStyle()

                            Button {
                                tempBirthTime = viewModel.birth_time
                                showTimePickerSheet = true
                            } label: {
                                HStack {
                                    Text(viewModel.birth_time.formatted(date: .omitted, time: .shortened))
                                        .foregroundColor(themeManager.onboardingPrimaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.9))
                                }
                                .padding()
                                .background(panelBG)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        Text(onboardingPrivacyNote)
                            .onboardingCaptionStyle()
                            .padding(.horizontal, 28)
                            .padding(.top, 2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink(
                            destination: OnboardingStep3(viewModel: viewModel)
                        ) {
                            Text("Continue")
                                .onboardingPrimaryButtonStyle()
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                    }
                }
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top + 8)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: max(12, geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(false)
                }

                OnboardingBackOverlay()
            }
            .onAppear {
                // 默认值兜底
                if viewModel.birth_date.timeIntervalSince1970 == 0 {
                    viewModel.birth_date = Date()
                }
                if viewModel.birth_time.timeIntervalSince1970 == 0 {
                    viewModel.birth_time = Date()
                }
            }
            // 日期滚轮
            .sheet(isPresented: $showDatePickerSheet) {
                pickerSheet {
                    DatePicker(
                        "",
                        selection: $tempBirthDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                } done: {
                    viewModel.birth_date = tempBirthDate
                    showDatePickerSheet = false
                }
                .presentationDetents([.fraction(0.45), .medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(themeManager.onboardingPanelFill)
            }
            // 时间滚轮（关键：保存时用 makeLocalDate 固定到本地时区的参考日，防止后续显示漂移）
            .sheet(isPresented: $showTimePickerSheet) {
                pickerSheet {
                    DatePicker(
                        "",
                        selection: $tempBirthTime,
                        displayedComponents: [.hourAndMinute]
                    )
                } done: {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: tempBirthTime)
                    if let d = makeLocalDate(hour: comps.hour ?? 0, minute: comps.minute ?? 0) {
                        viewModel.birth_time = d
                    } else {
                        viewModel.birth_time = tempBirthTime
                    }
                    showTimePickerSheet = false
                }
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(themeManager.onboardingPanelFill)
            }
        }
        // === 彻底隐藏系统导航条 & 返回按钮，去掉顶部白条 ===
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func pickerSheet<PickerContent: View>(
        @ViewBuilder content: () -> PickerContent,
        done: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button("Done", action: done)
                    .font(.custom("Merriweather-Bold", size: 16))
                    .foregroundColor(themeManager.onboardingPrimaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            content()
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.colorScheme, themeManager.isNight ? .dark : .light)
                .tint(themeManager.accent)
                .foregroundColor(themeManager.onboardingPrimaryText)
                .padding(.bottom, 18)
        }
    }
}

import SwiftUI
import MapKit
import CoreLocation

struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(subtitle)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}


import SwiftUI

struct OnboardingStep3: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    private var panelBG: Color { themeManager.onboardingPanelFill }
    private var stroke: Color { themeManager.onboardingPanelStroke }

    private let scentOptions  = ["Floral", "Strong", "Woody", "Citrus", "Spicy", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green", "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet", "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Classical", "Electronic", "Country", "Jazz", "Other"]

    private var hasAnySelection: Bool {
        !viewModel.scent_dislike.isEmpty ||
        !viewModel.color_dislike.isEmpty ||
        !viewModel.allergies.isEmpty ||
        !viewModel.music_dislike.isEmpty ||
        !viewModel.act_prefer.isEmpty
    }

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @State private var isLoading = false
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var loadingStageIndex: Int = 0
    @State private var showLongWaitHint = false
    @State private var loadingErrorMessage: String? = nil
    @State private var navigateToHome = false
    @StateObject private var appleAuth = AppleAuthManager()
    @State private var showLoadingOverlay = false

    @StateObject private var locationManager = LocationManager()
    @State private var locationMessage = "Requesting location permission..."
    @State private var didAttemptReverseGeocode = false

    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.top + 8)

                        AlignaTopHeader(minLength: minLength)

                        Text("Your preferences")
                            .onboardingTitleStyle()
                            .padding(.top, 6)

                        Text("This helps us personalize your daily rhythms")
                            .onboardingCaptionStyle()

                        preferenceSection(
                            "Any scent that don’t feel right?",
                            content: chips(options: scentOptions,
                                           isSelected: { viewModel.scent_dislike.contains($0) },
                                           toggle: { toggleSet(&viewModel.scent_dislike, $0) })
                        )

                        preferenceSection(
                            "Activity preference?",
                            content: chips(options: actOptions,
                                           isSelected: { viewModel.act_prefer.contains($0) },
                                           toggle: { toggleSet(&viewModel.act_prefer, $0) })
                        )

                        preferenceSection(
                            "Any color that don’t feel right?",
                            content: chips(options: colorOptions,
                                           isSelected: { viewModel.color_dislike.contains($0) },
                                           toggle: { toggleSet(&viewModel.color_dislike, $0) })
                        )

                        preferenceSection(
                            "Any allergies we should know about?",
                            content: chips(options: allergyOpts,
                                           isSelected: { viewModel.allergies.contains($0) },
                                           toggle: { toggleSet(&viewModel.allergies, $0) })
                        )

                        preferenceSection(
                            "Any sound that don’t feel right?",
                            content: chips(options: musicOptions,
                                           isSelected: { viewModel.music_dislike.contains($0) },
                                           toggle: { toggleSet(&viewModel.music_dislike, $0) })
                        )

                        Group {
                            Button {
                                guard !isLoading else { return }
                                loadingErrorMessage = nil
                                showLoadingOverlay = true
                                isLoading = true
                                loadingStageIndex = 0
                                showLongWaitHint = false
                                ensureAuthenticatedThenUpload()
                            } label: {
                                Text(hasAnySelection ? "Continue" : "Skip for now")
                                    .onboardingPrimaryButtonStyle(isEnabled: !isLoading)
                            }
                            .disabled(isLoading)
                            .padding(.horizontal, 0)
                            .padding(.top, 10)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                }

                OnboardingBackOverlay()

            }

            if showLoadingOverlay {
                loadingOverlay
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .onAppear {
            didAttemptReverseGeocode = false
            locationMessage = "Requesting location permission..."
            locationManager.requestLocation()
        }
        .onDisappear {
            if let handle = authListenerHandle {
                Auth.auth().removeStateDidChangeListener(handle)
                authListenerHandle = nil
            }
        }
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
            if !viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !isCoordinateLikeString(viewModel.currentPlace) {
                return
            }
            guard !didAttemptReverseGeocode else { return }
            didAttemptReverseGeocode = true

            getAddressFromCoordinate(coord, preferredLocale: .current) { place in
                DispatchQueue.main.async {
                    if let place = place, !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.currentPlace = place
                        viewModel.currentCoordinate = coord
                        locationMessage = "✓ Current Place detected: \(place)"
                    } else {
                        viewModel.currentCoordinate = coord
                        let coordText = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                        viewModel.currentPlace = coordText
                        locationMessage = "Location acquired, resolving address failed."

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            didAttemptReverseGeocode = false
                        }
                    }
                }
            }
        }
        .onReceive(locationManager.$locationStatus.compactMap { $0 }) { status in
            switch status {
            case .denied, .restricted:
                locationMessage = "Location permission denied. Current place will be left blank."
            default:
                break
            }
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            PostOnboardingLoadingFlow()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
                .navigationBarBackButtonHidden(true)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func preferenceSection<Content: View>(_ title: String, content: Content) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(title)
                .onboardingQuestionStyle()
            content
        }
        .padding()
        .background(panelBG)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(stroke, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func chips(options: [String],
                       isSelected: @escaping (String) -> Bool,
                       toggle: @escaping (String) -> Void) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { opt in
                Button {
                    toggle(opt)
                } label: {
                    let selected = isSelected(opt)
                    Text(opt)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(selected ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.18 : 0.14) : panelBG)
                        .foregroundColor(selected ? themeManager.onboardingPrimaryText : themeManager.onboardingSecondaryText)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selected ? themeManager.onboardingPrimaryText.opacity(themeManager.isNight ? 0.55 : 0.35) : stroke, lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSet(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Preparing your profile…")
                    .font(.custom("Merriweather-Bold", size: 17))
                    .foregroundColor(themeManager.onboardingPrimaryText)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(themeManager.accent)
                        .scaleEffect(0.9)
                }

                if let error = loadingErrorMessage {
                    Text(error)
                        .font(AlynnaTypography.font(.footnote))
                        .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.85))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Close") {
                            showLoadingOverlay = false
                            loadingErrorMessage = nil
                        }
                        .font(.custom("Merriweather-Bold", size: 14))
                        .foregroundColor(themeManager.onboardingPrimaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(10)

                        Button("Retry") {
                            loadingErrorMessage = nil
                            isLoading = true
                            loadingStageIndex = 0
                            showLongWaitHint = false
                            ensureAuthenticatedThenUpload()
                        }
                        .font(.custom("Merriweather-Bold", size: 14))
                        .foregroundColor(themeManager.onboardingPrimaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                } else {
                    Text("This may take around a minute.")
                        .font(AlynnaTypography.font(.footnote))
                        .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.75))

                    Text(loadingStageText)
                        .font(AlynnaTypography.font(.footnote))
                        .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.75))

                    if showLongWaitHint {
                        Text("Still working—hang tight.")
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.onboardingPanelStroke.opacity(0.7), lineWidth: 1)
            )
            .frame(maxWidth: 320)
        }
    }

    private var loadingStageText: String {
        let stages = [
            "Saving your preferences…",
            "Personalizing your profile…",
            "Finalizing recommendations…"
        ]
        if stages.isEmpty { return "" }
        return stages[min(loadingStageIndex, stages.count - 1)]
    }

    private func startLoadingStages() {
        loadingStageIndex = 0
        showLongWaitHint = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.isLoading { self.loadingStageIndex = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading { self.loadingStageIndex = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isLoading { self.showLongWaitHint = true }
        }
    }

    private func ensureAuthenticatedThenUpload() {
        uploadUserInfo()
    }

    private func attemptGoogleRestoreOrSignIn(completion: @escaping (Bool) -> Void) {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
                if let user = user, let idToken = user.idToken?.tokenString {
                    let credential = GoogleAuthProvider.credential(
                        withIDToken: idToken,
                        accessToken: user.accessToken.tokenString
                    )
                    Auth.auth().signIn(with: credential) { _, err in
                        if err != nil {
                            self.presentInteractiveGoogleSignIn(completion: completion)
                        } else {
                            completion(true)
                        }
                    }
                } else {
                    self.presentInteractiveGoogleSignIn(completion: completion)
                }
            }
        } else {
            presentInteractiveGoogleSignIn(completion: completion)
        }
    }

    private func presentInteractiveGoogleSignIn(completion: @escaping (Bool) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(false)
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = UIApplication.shared.topViewController_aligna else {
            completion(false)
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { signInResult, signInError in
            if let signInError = signInError {
                print("❌ Google sign-in failed: \(signInError.localizedDescription)")
                completion(false)
                return
            }
            guard
                let user = signInResult?.user,
                let idToken = user.idToken?.tokenString
            else {
                completion(false)
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, err in
                completion(err == nil)
            }
        }
    }

    private func presentInteractiveAppleSignIn(completion: @escaping (Bool) -> Void) {
        let nonce = randomNonceString()
        appleAuth.startSignUp(nonce: nonce) { result in
            switch result {
            case .success(let authorization):
                guard
                    let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let identityToken = appleIDCredential.identityToken,
                    let tokenString = String(data: identityToken, encoding: .utf8)
                else {
                    completion(false)
                    return
                }
                let credential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: tokenString,
                    rawNonce: nonce
                )
                Auth.auth().signIn(with: credential) { _, err in
                    completion(err == nil)
                }
            case .failure:
                completion(false)
            }
        }
    }

    private func uploadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法上传")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            showLoadingOverlay = false
            return
        }

        let db = Firestore.firestore()

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        let (h, m) = BirthTimeUtils.hourMinute(from: viewModel.birth_time)

        let lat = viewModel.currentCoordinate?.latitude ?? 0
        let lng = viewModel.currentCoordinate?.longitude ?? 0
        let currentPlace = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPlace = currentPlace.isEmpty ? "Unknown" : currentPlace

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        var data: [String: Any] = [
            "uid": userId,
            "nickname": viewModel.nickname,
            "gender": viewModel.gender,
            "relationshipStatus": viewModel.relationshipStatus,
            "birthDate": birthDateString,
            "birthTime": birthTimeString,
            "birthHour": h,
            "birthMinute": m,
            "birthPlace": viewModel.birthPlace,
            "currentPlace": resolvedPlace,
            "birthLat": viewModel.birthCoordinate?.latitude ?? 0,
            "birthLng": viewModel.birthCoordinate?.longitude ?? 0,
            "currentLat": lat,
            "currentLng": lng,
            "createdAt": Timestamp(),
            "scent_dislike": Array(viewModel.scent_dislike),
            "act_prefer": Array(viewModel.act_prefer),
            "color_dislike": Array(viewModel.color_dislike),
            "allergies": Array(viewModel.allergies),
            "music_dislike": Array(viewModel.music_dislike)
        ]

        data["birthday"] = Timestamp(date: viewModel.birth_date)

        let ref = db.collection("users").document(userId)
        ref.setData(data, merge: true) { error in
            if let error = error {
                print("❌ Firebase 写入失败: \(error)")
            } else {
                print("✅ 用户信息已保存/更新（users/\(userId)）")
                hasCompletedOnboarding = true
            }
        }

        startLoadingStages()

        var payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        if let v = viewModel.geomagneticDeclinationDeg {
            payload["geomagnetic_declination_deg"] = v
        }
        if let v = viewModel.geomagneticDeclinationSvDegPerYear {
            payload["geomagnetic_declination_sv_deg_per_year"] = v
        }
        if let v = viewModel.geomagneticDeclinationUncertaintyDeg {
            payload["geomagnetic_declination_uncertainty_deg"] = v
        }
        if let v = viewModel.geomagneticElevationKm {
            payload["geomagnetic_elevation_km"] = v
        }

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            loadingErrorMessage = "Couldn’t reach the server. Please try again."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            loadingErrorMessage = "Couldn’t prepare your data. Please try again."
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                    loadingStageIndex = 0
                    showLongWaitHint = false
                    loadingErrorMessage = "Network error. Please try again."
                }
                return
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8),
                  let cleanedData = raw.data(using: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                DispatchQueue.main.async {
                    isLoading = false
                    loadingStageIndex = 0
                    showLongWaitHint = false
                    loadingErrorMessage = "No response from server. Please try again."
                }
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantraText = parsed["mantra"] as? String {

                    func canonicalCategoryKey(_ raw: String) -> String? {
                        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                        case "place": return "Place"
                        case "gemstone": return "Gemstone"
                        case "color": return "Color"
                        case "scent": return "Scent"
                        case "activity": return "Activity"
                        case "sound": return "Sound"
                        case "career": return "Career"
                        case "relationship": return "Relationship"
                        default: return nil
                        }
                    }

                    func sanitizeDocName(_ raw: String) -> String {
                        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
                        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    let normalizedRecs: [String: String] = recs.reduce(into: [:]) { acc, pair in
                        guard let canon = canonicalCategoryKey(pair.key) else { return }
                        acc[canon] = sanitizeDocName(pair.value)
                    }

                    func coerceStringDict(_ any: Any?) -> [String: String] {
                        if let dict = any as? [String: String] { return dict }
                        guard let dict = any as? [String: Any] else { return [:] }
                        return dict.reduce(into: [String: String]()) { acc, pair in
                            if let s = pair.value as? String { acc[pair.key] = s }
                        }
                    }

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

                    print("🧠 FastAPI(raw) reasoning count:", rawReasoning.count, "keys:", rawReasoning.keys.sorted())

                    DispatchQueue.main.async {
                        viewModel.recommendations = normalizedRecs
                        isLoading = false
                        loadingStageIndex = 0
                        showLongWaitHint = false

                        guard let userId = Auth.auth().currentUser?.uid else { return }
                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                        let createdAt = df.string(from: Date())

                        var recommendationData: [String: Any] = normalizedRecs
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = createdAt
                        recommendationData["mantra"] = mantraText

                        if !rawReasoning.isEmpty {
                            recommendationData["reasoning"] = rawReasoning
                            recommendationData["mapping"] = rawReasoning
                        }

                        let docId = "\(userId)_\(createdAt)"
                        Firestore.firestore()
                            .collection("daily_recommendation")
                            .document(docId)
                            .setData(recommendationData, merge: true) { error in
                                if let error = error {
                                    print("❌ 保存 daily_recommendation 失败：\(error)")
                                } else {
                                    print("✅ 推荐结果保存成功（幂等写入）")
                                    UserDefaults.standard.set(createdAt, forKey: "lastRecommendationDate")
                                }
                            }

                        isLoggedIn = true
                        hasCompletedOnboarding = true
                        shouldOnboardAfterSignIn = false
                        showLoadingOverlay = false
                        navigateToHome = true
                    }
                } else {
                    print("❌ JSON 解包失败或缺少字段")
                    DispatchQueue.main.async {
                        isLoading = false
                        loadingStageIndex = 0
                        showLongWaitHint = false
                        loadingErrorMessage = "Something went wrong. Please try again."
                    }
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                    loadingStageIndex = 0
                    showLongWaitHint = false
                    loadingErrorMessage = "Couldn’t read the server response. Please try again."
                }
            }
        }.resume()
    }
}

// ===============================
// MARK: - FlexibleWrap / FlowLayout（修复版）
// ===============================
struct FlexibleWrap<Content: View>: View {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        // 注意：这里返回的是 FlowLayout{ ... }，不是再次调用 FlexibleWrap 本身
        FlowLayout(spacing: spacing, runSpacing: runSpacing) {
            content()
        }
    }
}

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12

    // ❗️不要写带 @ViewBuilder 的 init，会覆盖系统合成的带内容闭包的初始化
    init(spacing: CGFloat = 12, runSpacing: CGFloat = 12) {
        self.spacing = spacing
        self.runSpacing = runSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews, placing: false)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        _ = layout(proposal: proposal, subviews: subviews, placing: true, in: bounds)
    }

    private func layout(proposal: ProposedViewSize,
                        subviews: Subviews,
                        placing: Bool,
                        in bounds: CGRect = .zero) -> CGSize {
        let maxWidth = proposal.width ?? (placing ? bounds.width : .greatestFiniteMagnitude)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }

            if placing {
                let origin = CGPoint(x: bounds.minX + x, y: bounds.minY + y)
                sv.place(at: origin, proposal: .unspecified)
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }
}



import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var currentAltitudeMeters: Double?
    @Published var locationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25   // 25m 再更新，减少抖动
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        // 单次请求即可，系统会在拿到最新定位后回调一次
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = last.coordinate
            self.currentAltitudeMeters = last.altitude
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 获取位置失败: \(error.localizedDescription)")
    }
}


class SearchDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    var onResults: ([MKLocalSearchCompletion]) -> Void = { _ in }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }
}


import SwiftUI
import CoreLocation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct OnboardingFinalStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false


    // 位置 & 流程
    @StateObject private var locationManager = LocationManager()
    @State private var locationMessage = "Requesting location permission..."
    @State private var didAttemptReverseGeocode = false

    // 上传/跳转
    @State private var isLoading = false
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var loadingStageIndex: Int = 0
    @State private var showLongWaitHint = false
    @State private var loadingErrorMessage: String? = nil
    @State private var navigateToHome = false
    @StateObject private var appleAuth = AppleAuthManager()

    // 入场动画
    @State private var showIntro = false
    private var panelBG: Color { themeManager.onboardingPanelFill }
    private var stroke: Color { themeManager.onboardingPanelStroke }

    var body: some View {
        GeometryReader { geo in
            let minL = min(geo.size.width, geo.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: minL * 0.045) {
                        Color.clear
                            .frame(height: geo.safeAreaInsets.top + 7)

                        AlignaTopHeader(minLength: minL)

                        Text("Confirm your information")
                            .onboardingTitleStyle()
                            .padding(.top, 6)
                            .staggered(1, show: $showIntro)

                        VStack(spacing: 7) {
                            finalInfoCard(title: "Nickname", value: viewModel.nickname)
                                .staggered(2, show: $showIntro)
                            finalInfoCard(title: "Gender", value: viewModel.gender)
                                .staggered(3, show: $showIntro)
                            finalInfoCard(
                                title: "Birthday",
                                value: viewModel.birth_date.formatted(.dateTime.year().month().day())
                            )
                            .staggered(4, show: $showIntro)
                            finalInfoCard(
                                title: "Time of Birth",
                                value: viewModel.birth_time.formatted(date: .omitted, time: .shortened)
                            )
                            .staggered(5, show: $showIntro)
                            finalInfoCard(
                                title: "Your Current Location",
                                value: viewModel.currentPlace.isEmpty ? locationMessage : viewModel.currentPlace
                            )
                            .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)

                        Group {
                            Button {
                                guard !isLoading else { return }
                                loadingErrorMessage = nil
                                isLoading = true
                                loadingStageIndex = 0
                                showLongWaitHint = false
                                ensureAuthenticatedThenUpload()
                            } label: {
                                ZStack {
                                    Text("Confirm")
                                        .onboardingPrimaryButtonStyle(isEnabled: !isLoading)
                                        .opacity(isLoading ? 0.0 : 1.0)

                                    if isLoading {
                                        HStack(spacing: 12) {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.black)
                                                .scaleEffect(0.8)
                                            Text("Preparing your profile…")
                                                .font(.custom("Merriweather-Bold", size: 17))
                                                .foregroundColor(themeManager.onboardingPrimaryText)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .staggered(8, show: $showIntro)

                            if isLoading {
                                Text("This may take a few seconds.")
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                    .padding(.top, 6)
                                    .transition(.opacity)

                                Text(loadingStageText)
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                    .padding(.top, 2)
                                    .transition(.opacity)

                                if showLongWaitHint {
                                    Text("Still working—hang tight.")
                                        .font(AlynnaTypography.font(.footnote))
                                        .foregroundColor(themeManager.fixedNightTextSecondary)
                                        .padding(.top, 2)
                                        .transition(.opacity)
                                }
                            }

                            if let error = loadingErrorMessage {
                                Text(error)
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                OnboardingBackOverlay()
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
            .onAppear {
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }

                // 进页面即发起位置权限与解析
                didAttemptReverseGeocode = false
                locationMessage = "Requesting location permission..."
                locationManager.requestLocation()
            }
            .onDisappear {
                if let handle = authListenerHandle {
                    Auth.auth().removeStateDidChangeListener(handle)
                    authListenerHandle = nil
                }
            }
            // 监听坐标，做反向地理编码
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                // ✅ 如果已经有可用城市名，就不重复解析
                if !viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !isCoordinateLikeString(viewModel.currentPlace) {
                    return
                }

                // ✅ 允许同一个页面多次尝试（第一次失败也能重试）
                guard !didAttemptReverseGeocode else { return }
                didAttemptReverseGeocode = true

                // ✅ 用你文件里更稳的 getAddressFromCoordinate（带重试 + 过滤）
                getAddressFromCoordinate(coord, preferredLocale: .current) { place in
                    DispatchQueue.main.async {
                        if let place = place, !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            viewModel.currentPlace = place
                            viewModel.currentCoordinate = coord
                            locationMessage = "✓ Current Place detected: \(place)"
                        } else {
                            // ✅ 失败也先显示坐标，避免“看不到定位”
                            viewModel.currentCoordinate = coord
                            let coordText = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                            viewModel.currentPlace = coordText
                            locationMessage = "Location acquired, resolving address failed."

                            // ✅ 关键：给一次“自动重试机会”
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                didAttemptReverseGeocode = false
                            }
                        }
                    }
                }
            }

            // 监听权限
            .onReceive(locationManager.$locationStatus.compactMap { $0 }) { status in
                switch status {
                case .denied, .restricted:
                    locationMessage = "Location permission denied. Current place will be left blank."
                default:
                    break
                }
            }
            // 完成后跳首页
            .fullScreenCover(isPresented: $navigateToHome) {
                PostOnboardingLoadingFlow()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func finalInfoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.onboardingSecondaryText.opacity(0.8))
                .tracking(0.6)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.custom("Merriweather-Bold", size: 17))
                .foregroundColor(themeManager.onboardingPrimaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(panelBG)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stroke, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - 反向地理编码
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            if let p = placemarks?.first {
                let city = p.locality ?? p.administrativeArea ?? p.name
                completion(city)
            } else {
                completion(nil)
            }
        }
    }

    // ====== 以下保持你原有逻辑：上传用户信息 + FastAPI 请求并写入 daily_recommendation ======
    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""

    private func ensureAuthenticatedThenUpload() {
        if Auth.auth().currentUser != nil {
            uploadUserInfo()
            return
        }

        attemptGoogleRestoreOrSignIn { success in
            if success {
                uploadUserInfo()
            } else {
                isLoading = false
                loadingStageIndex = 0
                showLongWaitHint = false
                loadingErrorMessage = "Sign-in is required to finish onboarding."
            }
        }
    }

    private func attemptGoogleRestoreOrSignIn(completion: @escaping (Bool) -> Void) {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
                if let user = user, let idToken = user.idToken?.tokenString {
                    let credential = GoogleAuthProvider.credential(
                        withIDToken: idToken,
                        accessToken: user.accessToken.tokenString
                    )
                    Auth.auth().signIn(with: credential) { _, err in
                        if err != nil {
                            self.presentInteractiveGoogleSignIn(completion: completion)
                        } else {
                            completion(true)
                        }
                    }
                } else {
                    self.presentInteractiveGoogleSignIn(completion: completion)
                }
            }
        } else {
            presentInteractiveGoogleSignIn(completion: completion)
        }
    }

    private func presentInteractiveGoogleSignIn(completion: @escaping (Bool) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            presentInteractiveAppleSignIn(completion: completion)
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = UIApplication.shared.topViewController_aligna else {
            presentInteractiveAppleSignIn(completion: completion)
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { signInResult, signInError in
            if let signInError = signInError {
                print("❌ Google sign-in failed: \(signInError.localizedDescription)")
                self.presentInteractiveAppleSignIn(completion: completion)
                return
            }
            guard
                let user = signInResult?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.presentInteractiveAppleSignIn(completion: completion)
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, err in
                if err != nil {
                    self.presentInteractiveAppleSignIn(completion: completion)
                } else {
                    completion(true)
                }
            }
        }
    }

    private func presentInteractiveAppleSignIn(completion: @escaping (Bool) -> Void) {
        let nonce = randomNonceString()
        appleAuth.startSignUp(nonce: nonce) { result in
            switch result {
            case .success(let authorization):
                guard
                    let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let identityToken = appleIDCredential.identityToken,
                    let tokenString = String(data: identityToken, encoding: .utf8)
                else {
                    completion(false)
                    return
                }
                let credential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: tokenString,
                    rawNonce: nonce
                )
                Auth.auth().signIn(with: credential) { _, err in
                    completion(err == nil)
                }
            case .failure:
                completion(false)
            }
        }
    }

    private var loadingStageText: String {
        let stages = [
            "Saving your preferences…",
            "Personalizing your profile…",
            "Finalizing recommendations…"
        ]
        if stages.isEmpty { return "" }
        return stages[min(loadingStageIndex, stages.count - 1)]
    }

    private func startLoadingStages() {
        loadingStageIndex = 0
        showLongWaitHint = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.isLoading { self.loadingStageIndex = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading { self.loadingStageIndex = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isLoading { self.showLongWaitHint = true }
        }
    }

    private func uploadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法上传")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            return
        }

        let db = Firestore.firestore()

        // 生日存成可读字符串（兼容你原有字段）
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        // ✅ 关键：只存“时、分”两个整型，彻底规避时区改动
        let (h, m) = BirthTimeUtils.hourMinute(from: viewModel.birth_time)

        let lat = viewModel.currentCoordinate?.latitude ?? 0
        let lng = viewModel.currentCoordinate?.longitude ?? 0

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        // ✅ 用 var，后面可追加字段
        var data: [String: Any] = [
            "uid": userId,
            "nickname": viewModel.nickname,
            "gender": viewModel.gender,
            "relationshipStatus": viewModel.relationshipStatus,
            "birthDate": birthDateString,          // 你原来的字符串生日
            "birthTime": birthTimeString,
            "birthHour": h,                        // ✅ 新增：小时
            "birthMinute": m,                      // ✅ 新增：分钟
            "birthPlace": viewModel.birthPlace,
            "currentPlace": viewModel.currentPlace,
            "birthLat": viewModel.birthCoordinate?.latitude ?? 0,
            "birthLng": viewModel.birthCoordinate?.longitude ?? 0,
            "currentLat": lat,
            "currentLng": lng,
            "createdAt": Timestamp()
        ]

        // 可选保留：同时写入一个 Timestamp 生日（仅用于“年月日”）
        data["birthday"] = Timestamp(date: viewModel.birth_date)

        // ✅ 固定 docId，避免重复文档
        let ref = db.collection("users").document(userId)
        ref.setData(data, merge: true) { error in
            if let error = error {
                print("❌ Firebase 写入失败: \(error)")
            } else {
                print("✅ 用户信息已保存/更新（users/\(userId)）")
                hasCompletedOnboarding = true
            }
        }

        // ===== 下面保持你原有的 FastAPI 请求逻辑 =====
        // 这里仍然用你原来传给后端的“字符串时间”，不会影响我们在 Firestore 的存储方案
        startLoadingStages()

        var payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        if let v = viewModel.geomagneticDeclinationDeg {
            payload["geomagnetic_declination_deg"] = v
        }
        if let v = viewModel.geomagneticDeclinationSvDegPerYear {
            payload["geomagnetic_declination_sv_deg_per_year"] = v
        }
        if let v = viewModel.geomagneticDeclinationUncertaintyDeg {
            payload["geomagnetic_declination_uncertainty_deg"] = v
        }
        if let v = viewModel.geomagneticElevationKm {
            payload["geomagnetic_elevation_km"] = v
        }

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            isLoading = false
            loadingStageIndex = 0
            showLongWaitHint = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                    loadingStageIndex = 0
                    showLongWaitHint = false
                }
                return
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8),
                  let cleanedData = raw.data(using: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                DispatchQueue.main.async {
                    isLoading = false
                    loadingStageIndex = 0
                    showLongWaitHint = false
                }
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantraText = parsed["mantra"] as? String {
                    
                    func canonicalCategoryKey(_ raw: String) -> String? {
                        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                        case "place": return "Place"
                        case "gemstone": return "Gemstone"
                        case "color": return "Color"
                        case "scent": return "Scent"
                        case "activity": return "Activity"
                        case "sound": return "Sound"
                        case "career": return "Career"
                        case "relationship": return "Relationship"
                        default: return nil
                        }
                    }

                    func sanitizeDocName(_ raw: String) -> String {
                        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
                        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    let normalizedRecs: [String: String] = recs.reduce(into: [:]) { acc, pair in
                        guard let canon = canonicalCategoryKey(pair.key) else { return }
                        acc[canon] = sanitizeDocName(pair.value)
                    }
                    
                    
                    // Optional per-category reasoning from backend.
                    // Supports:
                    //  - top-level "mapping": { "Place": "...", ... }
                    //  - legacy "reasoning": { ... } or "reasoning": { "mapping": { ... } }
                    func coerceStringDict(_ any: Any?) -> [String: String] {
                        if let dict = any as? [String: String] { return dict }
                        guard let dict = any as? [String: Any] else { return [:] }
                        return dict.reduce(into: [String: String]()) { acc, pair in
                            if let s = pair.value as? String { acc[pair.key] = s }
                        }
                    }

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

                    print("🧠 FastAPI(raw) reasoning count:", rawReasoning.count, "keys:", rawReasoning.keys.sorted())
                    
                    DispatchQueue.main.async {
                        viewModel.recommendations = normalizedRecs
                        self.isLoading = false
                        self.loadingStageIndex = 0
                        self.showLongWaitHint = false

                        guard let userId = Auth.auth().currentUser?.uid else { return }
                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                        let createdAt = df.string(from: Date())

                        var recommendationData: [String: Any] = normalizedRecs
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = createdAt
                        recommendationData["mantra"] = mantraText
                        
                        
                        if !rawReasoning.isEmpty {
                            // Write backend keys as-is (FastAPI returns canonical keys like "Place", "Color", ...)
                            recommendationData["reasoning"] = rawReasoning
                            recommendationData["mapping"] = rawReasoning
                        }

                        let docId = "\(userId)_\(createdAt)"
                        Firestore.firestore()
                            .collection("daily_recommendation")
                            .document(docId)
                            .setData(recommendationData, merge: true) { error in
                                if let error = error {
                                    print("❌ 保存 daily_recommendation 失败：\(error)")
                                } else {
                                    print("✅ 推荐结果保存成功（幂等写入）")
                                    UserDefaults.standard.set(createdAt, forKey: "lastRecommendationDate")
                                }
                            }

                        self.isLoggedIn = true
                        self.hasCompletedOnboarding = true
                        self.shouldOnboardAfterSignIn = false
                        navigateToHome = true
                    }
                } else {
                    print("❌ JSON 解包失败或缺少字段")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.loadingStageIndex = 0
                        self.showLongWaitHint = false
                    }
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadingStageIndex = 0
                    self.showLongWaitHint = false
                }
            }
        }.resume()
    }

}

private struct PostOnboardingLoadingFlow: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var showLoading = true

    var body: some View {
        ZStack {
            MainView()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
                .navigationBarBackButtonHidden(true)

            if showLoading {
                LoadingView(onStartLoading: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showLoading = false
                    }
                })
                .ignoresSafeArea()
            }
        }
    }
}

func firebaseCollectionName(for category: String) -> String {
    let mapping: [String: String] = [
        "Place": "places",
        "Gemstone": "gemstones",
        "Color": "colors",
        "Scent": "scents",
        "Activity": "activities",
        "Sound": "sounds",
        "Career": "careers",
        "Relationship": "relationships"
    ]
    return mapping[category] ?? ""
}


import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore
import UIKit

#if DEBUG
private struct OnboardingPreviewContainer<Content: View>: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    @StateObject private var viewModel: OnboardingViewModel

    private let wrapsInNavigationStack: Bool
    private let contentBuilder: (OnboardingViewModel) -> Content

    init(
        isNight: Bool = true,
        wrapsInNavigationStack: Bool = true,
        configure: ((OnboardingViewModel) -> Void)? = nil,
        @ViewBuilder content: @escaping (OnboardingViewModel) -> Content
    ) {
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)

        let viewModel = OnboardingViewModel()
        viewModel.nickname = "Luna"
        viewModel.birthPlace = "Hangzhou"
        viewModel.currentPlace = "San Francisco"
        viewModel.birth_date = Calendar.current.date(from: DateComponents(year: 1996, month: 3, day: 14)) ?? Date()
        viewModel.birth_time = BirthTimeUtils.makeLocalTimeDate(hour: 7, minute: 42)
        configure?(viewModel)
        _viewModel = StateObject(wrappedValue: viewModel)

        self.wrapsInNavigationStack = wrapsInNavigationStack
        self.contentBuilder = content
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack {
                    contentBuilder(viewModel)
                }
            } else {
                contentBuilder(viewModel)
            }
        }
        .environmentObject(starManager)
        .environmentObject(themeManager)
        .environmentObject(viewModel)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Onboarding Step 0") {
    OnboardingPreviewContainer { viewModel in
        OnboardingStep0(viewModel: viewModel)
    }
}

#Preview("Onboarding Step 1") {
    OnboardingPreviewContainer { viewModel in
        OnboardingStep1(viewModel: viewModel)
    }
}

#Preview("Onboarding Step 2") {
    OnboardingPreviewContainer(configure: { viewModel in
        viewModel.birth_date = Calendar.current.date(from: DateComponents(year: 1996, month: 3, day: 14)) ?? Date()
        viewModel.birth_time = BirthTimeUtils.makeLocalTimeDate(hour: 7, minute: 42)
    }) { viewModel in
        OnboardingStep2(viewModel: viewModel)
    }
}

#Preview("Onboarding Step 3") {
    OnboardingPreviewContainer(configure: { viewModel in
        viewModel.scent_dislike = ["Floral", "Strong"]
        viewModel.act_prefer = ["Dynamic"]
        viewModel.color_dislike = ["Yellow"]
        viewModel.allergies = ["Seasonal"]
        viewModel.music_dislike = ["Heavy metal"]
    }) { viewModel in
        OnboardingStep3(viewModel: viewModel)
    }
}

#endif
