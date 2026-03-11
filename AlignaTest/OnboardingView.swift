import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit

class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var gender: String = ""
    @Published var relationshipStatus: String = ""
    @Published var birth_date: Date = Date()
    @Published var birth_time: Date = Date()
    @Published var birthPlace: String = ""
    @Published var currentPlace: String = ""
    @Published var birthCoordinate: CLLocationCoordinate2D?
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var recommendations: [String: String] = [:]
    @Published var dailyMantra: String = ""
    @Published var reasoningSummary: String = ""

    
    // ✅ 新增：Step3 的五个答案
    @Published var scent_dislike: Set<String> = []     // 多选
    @Published var act_prefer: String = ""             // 单选，可清空
    @Published var color_dislike: Set<String> = []     // 多选
    @Published var allergies: Set<String> = []         // 多选
    @Published var music_dislike: Set<String> = []     // 多选
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
                    .font(Font.custom("CormorantGaramond-Bold", size: fontSize))
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




struct OnboardingView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                    
                    VStack(spacing: minLength * 0.04) {
                        Spacer()
                        
                        Text("Alynna")
                            .font(Font.custom("CormorantGaramond-Bold", size: minLength * 0.12))
                            .foregroundColor(themeManager.fixedNightTextPrimary)
                        
                        Text("Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care.")
                            .font(AlignaTypography.font(.subheadline))
                            .foregroundColor(themeManager.fixedNightTextSecondary)
                        
                        Image("openingSymbol")
                            .resizable()
                            .scaledToFit()
                            .frame(width: minLength * 0.35)
                        
                        Spacer()
                        
                        // Sign Up（按钮本身用白底黑字，保持原样）
                        NavigationLink(destination: RegisterView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)) {
                                Text("Sign Up")
                                    .font(AlignaTypography.font(.headline))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal, minLength * 0.1)
                            }

                        // Log In（按钮文案保留白色）
                        NavigationLink(destination: ProfileView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .environmentObject(OnboardingViewModel())) {
                                Text("Log In")
                                    .font(AlignaTypography.font(.headline))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal, minLength * 0.1)
                            }

                        Text("Welcome to the Journal of Alynna")
                            .font(AlignaTypography.font(.footnote))
                            .foregroundColor(themeManager.fixedNightTextTertiary)
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(.bottom, geometry.size.height * 0.05)
                    .preferredColorScheme(.dark)
                }
            }
        }
        .onAppear { starManager.animateStar = true }
        .navigationBarBackButtonHidden(true)
    }
}

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import FirebaseFirestore

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToOnboarding = false
    @State private var navigateToLogin = false
    @State private var currentNonce: String? = nil
    
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    
    @StateObject private var appleAuth = AppleAuthManager()


    // 入场动画控制
    @State private var showIntro = false

    // 焦点控制
    @FocusState private var registerFocus: RegisterField?
    private enum RegisterField { case email, password }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minL = min(w, h)

                let sectionGap  = h * 0.075
                let fieldGap    = minL * 0.030
                let socialGap   = minL * 0.035

                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)

                    VStack(spacing: 0) {
                        // 顶部：返回 + 标题
                        VStack(spacing: minL * 0.02) {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(themeManager.fixedNightTextPrimary)
                                        .padding(10)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .padding(.leading, w * 0.05)
                                Spacer()
                            }

                            VStack(spacing: 8) {
                                AlignaHeading(
                                    textColor: themeManager.fixedNightTextPrimary,
                                    show: $showIntro,
                                    fontSize: minL * 0.12,
                                    letterSpacing: minL * 0.005
                                )
                                Text("Create Account")
                                    .font(.custom("CormorantGaramond-Regular", size: 28))
                                    .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.9))
                            }
                            .padding(.top, h * 0.01)
                            .staggered(1, show: $showIntro)
                        }
                        .padding(.top, h * 0.05)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        // 表单
                        VStack(spacing: fieldGap) {

                            // Email
                            Group {
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .focused($registerFocus, equals: .email)
                                    .focusGlow(
                                        active: registerFocus == .email,
                                        color: themeManager.fixedNightTextPrimary,
                                        lineWidth: 2.2,
                                        cornerRadius: 14
                                    )
                                    .submitLabel(.next)
                                    .onSubmit { registerFocus = .password }
                            }
                            .staggered(2, show: $showIntro)
                            .animation(nil, value: registerFocus)

                            // Password
                            Group {
                                SecureField("Password", text: $password)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .focused($registerFocus, equals: .password)
                                    .focusGlow(
                                        active: registerFocus == .password,
                                        color: themeManager.fixedNightTextPrimary,
                                        lineWidth: 2.2,
                                        cornerRadius: 14
                                    )
                                    .submitLabel(.done)
                            }
                            .staggered(3, show: $showIntro)
                            .animation(nil, value: registerFocus)

                            Button(action: { registerWithEmailPassword() }) {
                                Text("Register & Send Email")
                                    .font(AlignaTypography.font(.headline))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.fixedNightTextPrimary)
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                            }
                            .staggered(4, show: $showIntro)
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: sectionGap)

                        // 第三方登录
                        VStack(spacing: socialGap) {
                            Text("Or register with")
                                .font(AlignaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                                .staggered(5, show: $showIntro)

                            HStack(spacing: minL * 0.10) {
                                // Google
                                Button(action: {
                                    // ① 预设标记（你原有逻辑，保留）
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    // ② 自检：没过就给出友好提示并 return
                                    if !GoogleSignInDiagnostics.preflight(context: "RegisterView.GoogleButton") {
                                        alertMessage = """
                                        """
                                        showAlert = true
                                        return
                                    }

                                    // ③ 通过预检 → 执行你原有的注册逻辑
                                    handleGoogleFromRegister(
                                        onNewUserGoOnboarding: {
                                            shouldOnboardAfterSignIn = true
                                            navigateToOnboarding = true
                                        },
                                        onExistingUserGoLogin: { msg in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = msg; showAlert = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                navigateToLogin = true
                                            }
                                        },
                                        onError: { message in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = message; showAlert = true
                                        }
                                    )
                                }) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .padding(14)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .staggered(6, show: $showIntro)

                                // Apple (custom - reliable)
                                Button {
                                    // 1) 预设标记
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    // 2) nonce
                                    let nonce = randomNonceString()
                                    currentNonce = nonce

                                    print("🍎 [Apple] Tap -> start authorization. nonce=\(nonce)")

                                    // 3) 启动 Apple 授权
                                    appleAuth.startSignUp(nonce: nonce) { result in
                                        // ✅ nonce 必须存在
                                        guard let raw = currentNonce, !raw.isEmpty else {
                                            DispatchQueue.main.async {
                                                shouldOnboardAfterSignIn = false
                                                alertMessage = "Missing nonce. Please try again."
                                                showAlert = true
                                            }
                                            return
                                        }

                                        handleAppleFromRegister(
                                            result: result,
                                            rawNonce: raw,
                                            onNewUserGoOnboarding: {
                                                DispatchQueue.main.async {
                                                    shouldOnboardAfterSignIn = true
                                                    navigateToOnboarding = true
                                                }
                                            },
                                            onExistingUserGoLogin: { msg in
                                                DispatchQueue.main.async {
                                                    shouldOnboardAfterSignIn = false
                                                    alertMessage = msg
                                                    showAlert = true
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    navigateToLogin = true
                                                }
                                            },
                                            onError: { message in
                                                DispatchQueue.main.async {
                                                    shouldOnboardAfterSignIn = false
                                                    alertMessage = message
                                                    showAlert = true
                                                }
                                            }
                                        )
                                    }

                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Sign up")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(width: 160, height: 50)
                                    .foregroundColor(.white)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .staggered(7, show: $showIntro)

                            }
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: h * 0.08)
                    }
                    .preferredColorScheme(.dark)
                    .transaction { $0.animation = nil } // 阻断布局隐式动画
                }
                .hideKeyboardOnTapOutside($registerFocus)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Notice"),
                          message: Text(alertMessage),
                          dismissButton: .default(Text("OK")))
                }
                .navigationDestination(isPresented: $navigateToOnboarding) {
                    OnboardingStep1(viewModel: viewModel)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                }
                .navigationDestination(isPresented: $navigateToLogin) {
                    ProfileView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .environmentObject(viewModel)
                }
                .onAppear {
                    showIntro = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        registerFocus = .email
                    }
                    _ = GoogleSignInDiagnostics.run(context: "RegisterView.onAppear")
                }
                .onDisappear { showIntro = false }
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { registerFocus = nil }
                    }
                }
            }
        }
    }

    // MARK: - Email & Password 注册（保留你的原逻辑）
    // MARK: - Email & Password 注册（跳转到 Onboarding）
    // MARK: - Email & Password 注册（跳转到 Onboarding）
    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        
        // ✅ 关键：在调用 createUser 之前，先打上“需要 Onboarding”的标记
        hasCompletedOnboarding = false
        isLoggedIn = false
        shouldOnboardAfterSignIn = true
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                // 特殊处理：邮箱已经被注册 → 引导去登录
                if let errCode = AuthErrorCode(rawValue: error._code),
                   errCode == .emailAlreadyInUse {
                    
                    // 这个情况其实是“老用户”，所以这里顺便把标记改回来也可以
                    shouldOnboardAfterSignIn = false
                    isLoggedIn = false
                    hasCompletedOnboarding = false
                    
                    alertMessage = "This email is already in use. Redirecting to Sign In..."
                    showAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        navigateToLogin = true
                    }
                    return
                }
                
                // 其他错误，直接弹出
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            // ✅ 账号创建成功：发验证邮件（就算失败也不影响继续 Onboarding）
            result?.user.sendEmailVerification(completion: nil)
            
            // 此时 FirstPageView 那个监听已经看到 shouldOnboardAfterSignIn = true，
            // 不会把你拉去首页，只会保持在 .onboarding。
            // 这里我们用本页的 NavigationStack 去推 OnboardingStep1。
            DispatchQueue.main.async {
                navigateToOnboarding = true
            }
        }
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
    var body: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
            Text("Alynna")
                .font(Font.custom("Merriweather-Regular", size: 34))
                .foregroundColor(.white)
        }
    }
}
extension Text {
    func onboardingQuestionStyle() -> some View {
        self.font(.custom("Merriweather-Regular", size: 17)) // 统一字号
            .foregroundColor(.white) // 统一颜色
            .multilineTextAlignment(.center) // 统一居中
            .frame(maxWidth: .infinity)
    }
}




import SwiftUI
import MapKit

struct OnboardingStep1: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    
    @State private var goOpening = false

    private let panelBG = Color.white.opacity(0.08)
    private let stroke   = Color.white.opacity(0.25)

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
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        // 顶部
                        AlignaTopHeader()

                        Text("Tell us about yourself")
                            .onboardingQuestionStyle()
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
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
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
                                            Text(gender)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(viewModel.gender == gender ? Color.white : panelBG)
                                                .foregroundColor(viewModel.gender == gender ? .black : .white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(stroke, lineWidth: 1)
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

                                // ✅ Fix: avoid overflow by NOT adding horizontal padding outside the fixed width frame
                                GeometryReader { geo in
                                    let total = geo.size.width
                                    let spacing: CGFloat = 10
                                    let available = total - spacing * 2

                                    // left/right a bit narrower, middle wider
                                    let sideW = available * 0.25
                                    let midW  = available - sideW * 2

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
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
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
                                    .font(.footnote)
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
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(panelBG)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Continue
                        NavigationLink(
                            destination: OnboardingStep2(viewModel: viewModel)
                                .environmentObject(themeManager)
                        ) {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormComplete ? Color.white : Color.white.opacity(0.1))
                                .foregroundColor(isFormComplete ? .black : .white)
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(isFormComplete ? 0.15 : 0),
                                        radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        .disabled(!isFormComplete)

                        // Back
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
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
            }
            .preferredColorScheme(.dark)
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
        // only vertical padding so width won't expand beyond .frame(width:)
        .padding(.vertical, 10)
        .background(viewModel.relationshipStatus == status ? Color.white : panelBG)
        .foregroundColor(viewModel.relationshipStatus == status ? .black : .white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(stroke, lineWidth: 1)
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

// MARK: - OnboardingStep2（顶部与 Step1/Step3 一致，日期/时间用弹出滚轮）
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

    private let panelBG = Color.white.opacity(0.08)
    private let stroke  = Color.white.opacity(0.25)

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
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                VStack(spacing: minLength * 0.05) {
                    // 顶部与 Step1 保持一致（无系统返回）
                    AlignaTopHeader()

                    Text("When were you born?")
                        .onboardingQuestionStyle()
                        .padding(.top, 10)

                    // Birthday
                    VStack(spacing: 15) {
                        Text("Birthday").onboardingQuestionStyle()

                        Button {
                            tempBirthDate = viewModel.birth_date
                            showDatePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_date.formatted(.dateTime.year().month(.wide).day()))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Time of Birth
                    VStack(spacing: 15) {
                        Text("Time of Your Birth").onboardingQuestionStyle()

                        Button {
                            tempBirthTime = viewModel.birth_time
                            showTimePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_time.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Continue
                    NavigationLink(
                        destination: OnboardingStep3(viewModel: viewModel)
                    ) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    // Back（自定义返回按钮，不用系统自带的）
                    Button(action: { dismiss() }) {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)
                    .padding(.bottom, 30)
                }
                .preferredColorScheme(.dark)
                .padding(.horizontal)
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
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            viewModel.birth_date = tempBirthDate
                            showDatePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.45), .medium])
                .background(.black.opacity(0.6))
            }
            // 时间滚轮（关键：保存时用 makeLocalDate 固定到本地时区的参考日，防止后续显示漂移）
            .sheet(isPresented: $showTimePickerSheet) {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: tempBirthTime)
                            if let d = makeLocalDate(hour: comps.hour ?? 0, minute: comps.minute ?? 0) {
                                viewModel.birth_time = d
                            } else {
                                viewModel.birth_time = tempBirthTime
                            }
                            showTimePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.35), .medium])
                .background(.black.opacity(0.6))
            }
        }
        // === 彻底隐藏系统导航条 & 返回按钮，去掉顶部白条 ===
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .ignoresSafeArea() // 防止出现顶边色带
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

    // 选项文案（对齐效果图）
    private let scentOptions  = ["Floral", "Strong", "Woody",
                                 "Citrus", "Spicy", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green",
                                 "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet",
                                 "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Classical", "Electronic",
                                 "Country", "Jazz", "Other"]

    private var hasAnySelection: Bool {
        !viewModel.scent_dislike.isEmpty ||
        !viewModel.color_dislike.isEmpty ||
        !viewModel.allergies.isEmpty ||
        !viewModel.music_dislike.isEmpty ||
        !viewModel.act_prefer.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackgroundView(mode: .night)
                .environmentObject(starManager)
                .environmentObject(themeManager)

            ScrollView {
                VStack(spacing: 24) {
                    header

                    // 说明
                    subHeader(
                        title: "A few quick preferences",
                        subtitle: "This helps us personalize your experience"
                    )

                    // Scents
                    sectionTitle("Any scents you dislike?")
                    chips(options: scentOptions,
                          isSelected: { viewModel.scent_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.scent_dislike, $0) })

                    // Activity
                    sectionTitle("Activity preference?")
                    chips(options: actOptions,
                          isSelected: { viewModel.act_prefer == $0 },
                          toggle: { toggleSingle(&viewModel.act_prefer, $0) })

                    // Colors
                    sectionTitle("Any colors you dislike?")
                    chips(options: colorOptions,
                          isSelected: { viewModel.color_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.color_dislike, $0) })

                    // Allergies
                    sectionTitle("Any allergies we should know about?")
                    chips(options: allergyOpts,
                          isSelected: { viewModel.allergies.contains($0) },
                          toggle: { toggleSet(&viewModel.allergies, $0) })

                    // Music
                    sectionTitle("Any music you dislike?")
                    chips(options: musicOptions,
                          isSelected: { viewModel.music_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.music_dislike, $0) })

                    // Continue / Continue without answers
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text(hasAnySelection ? "Continue" : "Continue without answers")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 8)

                    // Back
                    Button {
                        dismiss()
                    } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            // 顶部 Skip
            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                    }
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header（与 Step1/2 保持一致）
    private var header: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }

            Text("Alynna")
                .font(Font.custom("PlayfairDisplay-Regular", size: 34))
                .foregroundColor(.white)
        }
    }

    // 统一副说明的小字样式
    private func subHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).onboardingQuestionStyle()
            Text(subtitle)
                .onboardingQuestionStyle()
                .opacity(0.8)
        }
        .padding(.top, 6)
    }

    // 统一题干标题的小字样式
    private func sectionTitle(_ title: String) -> some View {
        Text(title).onboardingQuestionStyle()
    }

    // MARK: - 固定三列的 Chips（大小一致、间距一致）
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
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity) // 填满单元列宽
                        .frame(height: 44)          // 统一高度
                        .background(selected ? Color.white : Color.white.opacity(0.08))
                        .foregroundColor(selected ? .black : .white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(selected ? 0.0 : 0.25), lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toggle Helpers
    private func toggleSet(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
    private func toggleSingle(_ current: inout String, _ value: String) {
        current = (current == value) ? "" : value
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
        DispatchQueue.main.async { self.currentLocation = last.coordinate }
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
    @State private var navigateToHome = false

    // 入场动画
    @State private var showIntro = false

    var body: some View {
        GeometryReader { geo in
            let minL = min(geo.size.width, geo.size.height)

            // ===== 尺寸与间距（确保副标题 < 信息字体） =====
            let infoFontSize = max(18, minL * 0.046)           // 信息行字体（略大于 17，随屏变化）
            let subtitleFontSize = max(16, minL * 0.038)       // 副标题更小，始终 < infoFontSize
            let listItemSpacing = max(13, minL * 0.055)        // 信息项之间的垂直间距：更大
            let innerLineSpacing = max(3, minL * 0.016)        // 单个信息项内的行间距（多行时更松）

            ZStack {
                // 夜空背景（与 Step1~3 一致）
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: minL * 0.048) {
                        // 顶部：Logo + “Aligna”（逐字母入场）
                        VStack(spacing: 12) {
                            if let _ = UIImage(named: "alignaSymbol") {
                                Image("alignaSymbol")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: minL * 0.18, height: minL * 0.18)
                                    .staggered(0, show: $showIntro)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: minL * 0.18))
                                    .foregroundColor(.white)
                                    .staggered(0, show: $showIntro)
                            }

                            AlignaHeading(
                                textColor: .white,
                                show: $showIntro,
                                text: "Alynna",
                                fontSize: minL * 0.12,
                                perLetterDelay: 0.06,
                                duration: 0.22,
                                letterSpacing: minL * 0.004
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.top, minL * 0.06)

                        // ⬇️ 小副标题：明显小于信息字体
                        Text("Confirm your information")
                            .font(.custom("PlayfairDisplay-Regular", size: subtitleFontSize))
                            .foregroundColor(.white.opacity(0.95))
                            .kerning(minL * 0.0005)
                            .staggered(1, show: $showIntro)

                        // 信息条目：更大的项间距 + 更松的行间距
                        VStack(alignment: .leading, spacing: listItemSpacing) {
                            bulletRow(
                                emoji: "👤",
                                title: "Nickname",
                                value: viewModel.nickname,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(2, show: $showIntro)

                            bulletRow(
                                emoji: "⚧️",
                                title: "Gender",
                                value: viewModel.gender,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(3, show: $showIntro)

                            bulletRow(
                                emoji: "📅",
                                title: "Birthday",
                                value: viewModel.birth_date.formatted(.dateTime.year().month().day()),
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(4, show: $showIntro)

                            bulletRow(
                                emoji: "⏰",
                                title: "Time of Birth",
                                value: viewModel.birth_time.formatted(date: .omitted, time: .shortened),
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(5, show: $showIntro)

                            bulletRow(
                                emoji: "📍",
                                title: "Your Current Location",
                                value: viewModel.currentPlace.isEmpty ? locationMessage : viewModel.currentPlace,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)

                        // Loading
                        if isLoading {
                            ProgressView("Loading, please wait...")
                                .foregroundColor(.white)
                                .padding(.top, 6)
                                .staggered(7, show: $showIntro)
                        }

                        // ✅ 确认按钮（白底 + 黑字，与 Step1~3 一致）
                        Button {
                            guard !isLoading else { return }
                            isLoading = true
                            uploadUserInfo()
                        } label: {
                            Text("Confirm")
                                .font(AlignaTypography.font(.headline))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.top, 6)
                        .staggered(8, show: $showIntro)

                        // 返回（与 Step1~3 一致）
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(AlignaTypography.font(.headline))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.bottom, minL * 0.08)
                        .staggered(9, show: $showIntro)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }

                // 进页面即发起位置权限与解析
                didAttemptReverseGeocode = false
                locationMessage = "Requesting location permission..."
                locationManager.requestLocation()
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
            .navigationDestination(isPresented: $navigateToHome) {
                MainView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 单行条目（emoji + 斜体标题 + 正文字），支持传入字体与行距
    private func bulletRow(emoji: String, title: String, value: String, fontSize: CGFloat, lineSpacing: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 24, alignment: .center)

            // 组合文本：title 斜体，value 正常体；同一字号，内部行距更松
            (
                Text("\(title): ")
                    .italic()
                    .font(.custom("Merriweather-Regular", size: fontSize))
                +
                Text(value)
                    .font(.custom("Merriweather-Regular", size: fontSize))
            )
            .foregroundColor(.white)
            .lineSpacing(lineSpacing) // ⬅️ 单项内部行距（多行时生效）
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func uploadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法上传")
            isLoading = false
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

        // ✅ 用 var，后面可追加字段
        var data: [String: Any] = [
            "uid": userId,
            "nickname": viewModel.nickname,
            "gender": viewModel.gender,
            "relationshipStatus": viewModel.relationshipStatus,
            "birthDate": birthDateString,          // 你原来的字符串生日
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
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            isLoading = false
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
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async { isLoading = false }
                return
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8),
                  let cleanedData = raw.data(using: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                DispatchQueue.main.async { isLoading = false }
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
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
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

#Preview("Onboarding Intro") {
    OnboardingPreviewContainer { _ in
        OnboardingView()
    }
}

#Preview("Register") {
    OnboardingPreviewContainer { _ in
        RegisterView()
    }
}

#Preview("Onboarding Step 1") {
    OnboardingPreviewContainer { viewModel in
        OnboardingStep1(viewModel: viewModel)
    }
}

#Preview("Onboarding Final") {
    OnboardingPreviewContainer(configure: { viewModel in
        viewModel.nickname = "Luna"
        viewModel.birthPlace = "Hangzhou"
        viewModel.currentPlace = "San Francisco"
    }) { viewModel in
        OnboardingFinalStep(viewModel: viewModel)
    }
}
#endif
