#if DEBUG
private struct ProfilePreviewContainer<Content: View>: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    @StateObject private var viewModel = OnboardingViewModel()

    private let content: Content
    private let wrapsInNavigationStack: Bool

    init(
        theme: ThemePreference = .light,
        wrapsInNavigationStack: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        let themeManager = ThemeManager()
        switch theme {
        case .light:
            themeManager.selected = .day
        case .dark:
            themeManager.selected = .night
        case .auto:
            themeManager.selected = .system
        }
        _themeManager = StateObject(wrappedValue: themeManager)
        self.wrapsInNavigationStack = wrapsInNavigationStack
        self.content = content()
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack {
                    previewContent
                }
            } else {
                previewContent
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    private var previewContent: some View {
        ZStack {
            previewBaseColor
                .ignoresSafeArea()

            content
                .ignoresSafeArea()
        }
        .environmentObject(starManager)
        .environmentObject(themeManager)
        .environmentObject(viewModel)
    }

    private var previewBaseColor: Color {
        themeManager.isNight ? Color(hex: "#1a1a2e") : Color(hex: "#E6D9BD")
    }
}

#Preview("Profile Day") {
    ProfilePreviewContainer(theme: .light, wrapsInNavigationStack: false) {
        ProfileView(viewModel: OnboardingViewModel())
    }
}

#Preview("Profile Night") {
    ProfilePreviewContainer(theme: .dark, wrapsInNavigationStack: false) {
        ProfileView(viewModel: OnboardingViewModel())
    }
}
#endif
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit
import CryptoKit

struct ZodiacInlineRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let sunText: String
    let moonText: String
    let ascText: String

    private var normalizedAscText: String {
        let t = ascText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t.isEmpty || t == "—") ? "Unknown" : t
    }

    private var separator: some View {
        Text("•")
            .foregroundColor(themeManager.descriptionText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(systemIcon: String, text: String, italic: Bool = true) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemIcon)
                .imageScale(.small)
                .fixedSize(horizontal: true, vertical: false)

            Group {
                if italic {
                    Text(text).italic()
                } else {
                    Text(text)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .truncationMode(.tail)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            segment(systemIcon: "sun.max.fill", text: sunText)
            separator
            segment(systemIcon: "moon.fill", text: moonText)
            separator
            segment(systemIcon: "arrow.up.right", text: normalizedAscText)
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowContent
                .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                rowContent
                    .padding(.horizontal, 2)
            }
        }
        .font(.custom("Merriweather-Regular", size: UIFont.preferredFont(forTextStyle: .callout).pointSize, relativeTo: .callout))
        .foregroundColor(themeManager.primaryText)
        .accessibilityLabel(Text("Zodiac: Sun \(sunText), Moon \(moonText), Ascendant \(normalizedAscText)"))
    }
}

enum BirthTimeUtils {
    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeStyle = .short
        f.dateStyle = .none
        f.timeZone = .current
        return f
    }()

    static func hourMinute(from date: Date) -> (hour: Int, minute: Int) {
        let cal = Calendar.current
        return (cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    static func makeLocalTimeDate(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = .current
        comps.year = 2001
        comps.month = 1
        comps.day = 1
        comps.hour = hour
        comps.minute = minute
        return comps.date ?? Date()
    }
}

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }

        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct FocusGlow: ViewModifier {
    var active: Bool
    var color: Color = .white
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(active ? 0.95 : 0.28),
                            lineWidth: active ? lineWidth : 1)
            )
            .shadow(color: color.opacity(active ? 0.55 : 0.0), radius: active ? 10 : 0, x: 0, y: 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: active)
    }
}

extension View {
    func focusGlow(active: Bool,
                   color: Color = .white,
                   lineWidth: CGFloat = 2,
                   cornerRadius: CGFloat = 14) -> some View {
        modifier(FocusGlow(active: active, color: color, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}

extension ThemeManager {
    var fixedNightTextPrimary: Color   { Color(hex: "#E6D7C3") }
    var fixedNightTextSecondary: Color { Color(hex: "#B8C5D6") }
    var fixedNightTextTertiary: Color  { Color(hex: "#A8B5C8") }
}

struct ProfileLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentNonce: String? = nil
    @State private var navigateToHome = false
    @State private var authBusy = false

    // 入场动画
    @State private var showIntro = false

    // 焦点控制
    @FocusState private var loginFocus: LoginField?
    private enum LoginField { case email, password }

    private var panelBG: Color { Color.white.opacity(0.10) }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(mode: .night, nightMotion: .animated)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                VStack {
                    // 顶部返回
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(AlynnaTypography.font(.title3))
                                .padding()
                                .background(panelBG)
                                .clipShape(Circle())
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                        }
                        .padding(.leading, geometry.size.width * 0.05)
                        .padding(.top, geometry.size.height * 0.05)
                        Spacer()
                    }
                    .staggered(0, show: $showIntro)

                    Spacer(minLength: geometry.size.height * 0.03)

                    // 标题区
                    VStack(spacing: minLength * 0.02) {
                        AlignaHeading(
                            textColor: themeManager.fixedNightTextPrimary,
                            show: $showIntro,
                            fontSize: minLength * 0.12,
                            letterSpacing: minLength * 0.005
                        )

                        VStack(spacing: 6) {
                            Text("Welcome Back")
                                .font(AlynnaTypography.font(.title3))
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                            Text("Return to your journal, your rituals, and today's guidance.")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                    }
                    .staggered(1, show: $showIntro)

                    Spacer(minLength: geometry.size.height * 0.02)

                    // 表单
                    VStack(spacing: minLength * 0.035) {

                        // Email
                        Group {
                            TextField("", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(.vertical, 14)
                                .padding(.leading, 16)
                                .background(panelBG)
                                .cornerRadius(14)
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .placeholder(when: email.isEmpty) {
                                    Text("Enter your email")
                                        .foregroundColor(themeManager.fixedNightTextSecondary)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .email)
                                .focusGlow(
                                    active: loginFocus == .email,
                                    color: themeManager.fixedNightTextPrimary,
                                    lineWidth: 2,
                                    cornerRadius: 14
                                )
                                .submitLabel(.next)
                                .onSubmit { loginFocus = .password }
                        }
                        .staggered(2, show: $showIntro)
                        .animation(nil, value: loginFocus)

                        // Password
                        Group {
                            SecureField("", text: $password)
                                .padding(.vertical, 14)
                                .padding(.leading, 16)
                                .background(panelBG)
                                .cornerRadius(14)
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .placeholder(when: password.isEmpty) {
                                    Text("Enter your password")
                                        .foregroundColor(themeManager.fixedNightTextSecondary)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .password)
                                .focusGlow(
                                    active: loginFocus == .password,
                                    color: themeManager.fixedNightTextPrimary,
                                    lineWidth: 2,
                                    cornerRadius: 14
                                )
                                .submitLabel(.done)
                        }
                        .staggered(3, show: $showIntro)
                        .animation(nil, value: loginFocus)

                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                guard !authBusy else { return }
                                if email.isEmpty {
                                    alertMessage = "Enter your email first."
                                    showAlert = true
                                    return
                                }
                                authBusy = true
                                Auth.auth().sendPasswordReset(withEmail: email) { error in
                                    authBusy = false
                                    if let error = error {
                                        alertMessage = error.localizedDescription
                                    } else {
                                        alertMessage = "Password reset email sent."
                                    }
                                    showAlert = true
                                }
                            }
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.fixedNightTextSecondary)
                            .underline()
                        }
                        .staggered(4, show: $showIntro)

                        // Log In
                        Button(action: {
                            guard !authBusy else { return }
                            if email.isEmpty || password.isEmpty {
                                alertMessage = "Please enter both email and password."
                                showAlert = true
                                return
                            }
                            authBusy = true
                            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                                authBusy = false
                                if let error = error {
                                    if let code = AuthErrorCode(rawValue: (error as NSError).code) {
                                        switch code {
                                        case .wrongPassword: alertMessage = "Incorrect password. Please try again."
                                        case .invalidEmail: alertMessage = "Invalid email address."
                                        case .userDisabled: alertMessage = "This account has been disabled."
                                        case .userNotFound: alertMessage = "No account found with this email."
                                        default: alertMessage = error.localizedDescription
                                        }
                                    } else {
                                        alertMessage = error.localizedDescription
                                    }
                                    showAlert = true
                                    return
                                }
                                routeAuthenticatedUser(
                                    onSuccessToLogin: {
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        dismiss()
                                    },
                                    onError: { message in
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }
                        }) {
                            Text(authBusy ? "Signing in..." : "Log In")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.fixedNightTextPrimary)
                                .foregroundColor(.black)
                                .cornerRadius(14)
                        }
                        .disabled(authBusy)
                        .staggered(5, show: $showIntro)

                        // 分隔线
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                            Text("Or continue with")
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                        }
                        .staggered(6, show: $showIntro)

                        // Google / Apple
                        VStack(spacing: minLength * 0.025) {
                            Button(action: {
                                guard !authBusy else { return }
                                authBusy = true
                                handleGoogleLogin(
                                    viewModel: viewModel,
                                    onSuccessToLogin: {
                                        authBusy = false
                                        isLoggedIn = true
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        authBusy = false
                                    },
                                    onError: { message in
                                        authBusy = false
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }) {
                                HStack(spacing: 12) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(panelBG)
                                .cornerRadius(14)
                            }
                            .staggered(7, show: $showIntro)

                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    let nonce = randomNonceString()
                                    currentNonce = nonce
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = sha256(nonce)
                                },
                                onCompletion: { result in
                                    guard !authBusy else { return }
                                    guard let raw = currentNonce, !raw.isEmpty else {
                                        alertMessage = "Missing nonce. Please try again."
                                        showAlert = true
                                        return
                                    }
                                    authBusy = true
                                    handleAppleLogin(
                                        result: result,
                                        rawNonce: raw,
                                        onSuccessToLogin: {
                                            authBusy = false
                                            isLoggedIn = true
                                            navigateToHome = true
                                        },
                                        onSuccessToOnboarding: {
                                            authBusy = false
                                        },
                                        onError: { message in
                                            authBusy = false
                                            alertMessage = message
                                            showAlert = true
                                        }
                                    )
                                }
                            )
                            .frame(height: 50)
                            .signInWithAppleButtonStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .staggered(8, show: $showIntro)
                        }
                        .padding(.top, 2)

                        // 去注册
                        HStack {
                            Text("Don't have an account?")
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            NavigationLink(
                                destination: SignUpView()
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                                    .environmentObject(viewModel)
                            ) {
                            Text("Create Account")
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .underline()
                            }
                        }
                        .padding(.top)
                        .staggered(9, show: $showIntro)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    Spacer(minLength: geometry.size.height * 0.08)
                }
            }
            .navigationDestination(isPresented: $navigateToHome) {
                MainView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
            }
            .onDisappear { showIntro = false }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
// MARK: - 登录工具函数（可直接替换）
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import FirebaseCore
import UIKit

// 1) 查询用户是否已经在 users 表里存在
func checkIfUserAlreadyRegistered(uid: String, completion: @escaping (Bool) -> Void) {
    let db = Firestore.firestore()
    db.collection("users")
        .whereField("uid", isEqualTo: uid)
        .limit(to: 1)
        .getDocuments { snapshot, error in
            if let error = error {
                print("❌ 查询用户注册状态失败: \(error)")
                completion(false)
                return
            }
            let isRegistered = !(snapshot?.documents.isEmpty ?? true)
            print(isRegistered ? "✅ 用户已注册" : "🆕 用户未注册")
            completion(isRegistered)
        }
}

// 统一设置本地标记（保持你旧代码兼容性）
private func updateLocalFlagsForReturningUser() {
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
    print("🧭 Flags updated: hasCompletedOnboarding=true, isLoggedIn=true")
}

private func updateLocalFlagsForNeedsOnboarding() {
    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(true, forKey: "shouldOnboardAfterSignIn")
    UserDefaults.standard.set(false, forKey: "isLoggedIn")
}

private func clearLocalAuthFlags() {
    UserDefaults.standard.set(false, forKey: "isLoggedIn")
    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
    UserDefaults.standard.set("",    forKey: "lastRecommendationDate")
    UserDefaults.standard.set("",    forKey: "lastCurrentPlaceUpdate")
    UserDefaults.standard.set("",    forKey: "todayFetchLock")
}

extension Notification.Name {
    static let didDeleteAccount = Notification.Name("didDeleteAccount")
}

func routeAuthenticatedUser(
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    determineRegistrationPathForCurrentUser { path in
        DispatchQueue.main.async {
            switch path {
            case .existingAccount:
                updateLocalFlagsForReturningUser()
                onSuccessToLogin()
            case .needsOnboarding:
                updateLocalFlagsForNeedsOnboarding()
                onSuccessToOnboarding()
            }
        }
    }
}

private func routeAuthenticatedUser(
    uid: String,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void
) {
    determineRegistrationPathForUID(uid) { path in
        DispatchQueue.main.async {
            switch path {
            case .existingAccount:
                updateLocalFlagsForReturningUser()
                onSuccessToLogin()
            case .needsOnboarding:
                updateLocalFlagsForNeedsOnboarding()
                onSuccessToOnboarding()
            }
        }
    }
}

func signOutCurrentSession() throws {
    try Auth.auth().signOut()
    clearLocalAuthFlags()
    GIDSignIn.sharedInstance.signOut()
}

// 2) Google 登录（新版 withPresenting）
func handleGoogleLogin(
    viewModel: OnboardingViewModel,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase client ID.")
        return
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        onError("No root view controller.")
        return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            onError("Google Sign-In failed: \(error.localizedDescription)")
            return
        }
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            onError("Missing Google token.")
            return
        }

        let accessToken = user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Login failed: \(error.localizedDescription)")
                return
            }
            guard let uid = authResult?.user.uid else {
                onError("We couldn’t complete Google sign-in. Please try again.")
                return
            }

            if authResult?.additionalUserInfo?.isNewUser == true {
                try? signOutCurrentSession()
                onError("This Google account isn’t registered with Alynna yet. Please create an account first.")
                return
            }

            routeAuthenticatedUser(uid: uid, onSuccessToLogin: onSuccessToLogin, onSuccessToOnboarding: onSuccessToOnboarding)
        }
    }
}

// 3) Apple 登录
func handleAppleLogin(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    switch result {
    case .success(let authResults):
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple sign in failed, cannot obtain identity token.")
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,          // 或 AuthProviderID.apple
            idToken: tokenString,
            rawNonce: rawNonce
        )


        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Apple sign in failed: \(error.localizedDescription)")
                return
            }
            guard let uid = authResult?.user.uid else {
                onError("We couldn’t complete Apple sign-in. Please try again.")
                return
            }

            if authResult?.additionalUserInfo?.isNewUser == true {
                try? signOutCurrentSession()
                onError("This Apple account isn’t registered with Alynna yet. Please create an account first.")
                return
            }

            routeAuthenticatedUser(uid: uid, onSuccessToLogin: onSuccessToLogin, onSuccessToOnboarding: onSuccessToOnboarding)
        }

    case .failure(let error):
        onError("Apple authorization failed: \(error.localizedDescription)")
    }
}
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import UIKit
/// 替换你原有的 Google 注册逻辑（新版 API）
/// - onNewUserGoOnboarding: 新用户引导回调（进入 Step1）
/// - onExistingUserGoLogin: 老用户提示去登录的回调（传入提示文案）
/// - onError: 失败提示
func handleGoogleFromRegister(
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (_ message: String) -> Void
) {
    // 1) 准备配置与呈现控制器
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase clientID."); return
    }
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    guard let presenter = UIApplication.shared.topViewController_aligna else {
        onError("No presenting view controller."); return
    }

    // 2) 调起 Google 登录（新版 withPresenting）
    GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { signInResult, signInError in
        if let signInError = signInError {
            onError("Google sign-in failed: \(signInError.localizedDescription)")
            return
        }
        guard
            let user = signInResult?.user,
            let idToken = user.idToken?.tokenString
        else {
            onError("Empty Google sign-in result."); return
        }

        // 3) 用 Google 凭证登录 Firebase
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        Auth.auth().signIn(with: credential) { authResult, authError in
            if let authError = authError {
                onError("Firebase auth failed: \(authError.localizedDescription)")
                return
            }

            let isNew = authResult?.additionalUserInfo?.isNewUser ?? false
            if isNew {
                // 新用户：进入 Onboarding（你按钮里已经把 shouldOnboardAfterSignIn 置为 true）
                onNewUserGoOnboarding()
            } else {
                // 老用户：提示去登录页
                onExistingUserGoLogin("This Google account is already registered. Please sign in instead.")
            }
        }
    }
}

// ===============================
// 注册页专用：Apple（替换原函数）
// ===============================
func handleAppleFromRegister(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (String) -> Void
) {
    // ✅ rawNonce 必须存在
    guard !rawNonce.isEmpty else {
        DispatchQueue.main.async {
            onError("Missing nonce. Please try again.")
        }
        return
    }

    switch result {
    case .success(let authResults):
        guard
            let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential
        else {
            DispatchQueue.main.async {
                onError("Apple sign in failed: invalid credential.")
            }
            return
        }

        guard
            let identityToken = appleIDCredential.identityToken,
            let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            DispatchQueue.main.async {
                onError("Apple sign in failed: cannot extract identity token.")
            }
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenString,
            rawNonce: rawNonce
        )

        Auth.auth().signIn(with: credential) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    onError("Apple sign in failed: \(error.localizedDescription)")
                }
                return
            }

            // ✅ 按“资料完整度”分流
            determineRegistrationPathForCurrentUser { path in
                DispatchQueue.main.async {
                    switch path {
                    case .needsOnboarding:
                        onNewUserGoOnboarding()

                    case .existingAccount:
                        onExistingUserGoLogin("This Apple ID is already registered. Redirecting to Sign In…")
                        try? Auth.auth().signOut()
                    }
                }
            }
        }

    case .failure(let error):
        DispatchQueue.main.async {
            onError("Apple authorization failed: \(error.localizedDescription)")
        }
    }
}


// ===============================
// 辅助：基于“资料完整度”的分流（新增）
// ===============================

enum RegistrationPath { case needsOnboarding, existingAccount }

/// 读取当前登录用户在 Firestore 的档案；
/// 若无文档或文档不完整（缺少昵称/生日/出生时间/出生地），→ 需要 Onboarding；
/// 若文档完整 → 视为老用户。
func determineRegistrationPathForCurrentUser(
    completion: @escaping (RegistrationPath) -> Void
) {
    guard let uid = Auth.auth().currentUser?.uid else {
        completion(.needsOnboarding); return
    }
    determineRegistrationPathForUID(uid, completion: completion)
}

func determineRegistrationPathForUID(
    _ uid: String,
    completion: @escaping (RegistrationPath) -> Void
) {
    fetchUserDocByUID(uid) { data in
        guard let data = data else {
            // 没有任何用户文档 → 新用户
            completion(.needsOnboarding); return
        }
        completion(isProfileComplete(data) ? .existingAccount : .needsOnboarding)
    }
}

/// 依次在 "users" / "user" 集合中按 uid 查找文档，返回 data（任一命中即返回）
func fetchUserDocByUID(_ uid: String, completion: @escaping ([String: Any]?) -> Void) {
    let db = Firestore.firestore()
    let cols = ["users", "user"]
    func go(_ i: Int) {
        if i >= cols.count { completion(nil); return }
        db.collection(cols[i]).whereField("uid", isEqualTo: uid).limit(to: 1).getDocuments { snap, _ in
            if let data = snap?.documents.first?.data() { completion(data) }
            else { go(i + 1) }
        }
    }
    go(0)
}

/// 判定档案是否“完整”：
/// - 昵称 nickname: 非空
/// - 生日：支持两种历史字段：`birthday`(Timestamp) 或 `birthDate`(String) 任一存在
/// - 出生时间 birthTime: 非空字符串
/// - 出生地 birthPlace: 非空字符串
func isProfileComplete(_ d: [String: Any]) -> Bool {
    let nicknameOK   = (d["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    let hasBirthTS   = d["birthday"] is Timestamp
    let hasBirthStr  = ((d["birthDate"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    let birthDateOK  = hasBirthTS || hasBirthStr
    let birthTimeOK  = ((d["birthTime"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    let birthPlaceOK = ((d["birthPlace"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

    return nicknameOK && birthDateOK && birthTimeOK && birthPlaceOK
}



import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfo: Codable {
    var nickname: String
    var birth_date: String
    var birthPlace: String
    var birth_time: String
    var currentPlace: String
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// ========== Firestore Keys（不一致就改这里） ==========
private enum FSKeys {
    static let userPrimary   = "user"
    static let userAlt       = "users"
    static let recPrimary    = "daily recommendation"
    static let recAlt        = "daily_recommendation"
    static let chartData     = "chartData"

    static let uid           = "uid"
    static let email         = "email"
    static let nickname      = "nickname"
    static let birthday      = "birthday"   // Firestore Timestamp
    static let birthTime     = "birthTime"  // "h:mm a" 字符串
    static let birthPlace    = "birthPlace"
    static let currentPlace  = "currentPlace"
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// 主题偏好（轻/暗/系统）
enum ThemePreference: String, CaseIterable, Identifiable {
    case light, dark, auto
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .auto:  return "System"
        }
    }
    var icon: String  {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon.stars"
        case .auto:  return "gearshape"
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import AuthenticationServices
import FirebaseCore
import GoogleSignIn
import UIKit

// MARK: - Typography
enum AlynnaTypography {
    /// Keep the same *size* as a system text style, only swap the font face.
    static func font(_ textStyle: UIFont.TextStyle) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        switch textStyle {
        case .largeTitle, .title1, .title2, .title3:
            return .custom("Merriweather-Black", size: size)
        case .headline:
            return .custom("Merriweather-Bold", size: size)
        case .body, .callout, .subheadline:
            return .custom("Merriweather-Regular", size: size)
        case .footnote, .caption1, .caption2:
            return .custom("Merriweather-Light", size: size)
        default:
            return .custom("Merriweather-Regular", size: size)
        }
    }
}

struct AlignaCardStyle: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        themeManager.isNight
                        ? Color.white.opacity(0.04)
                        : Color.white.opacity(0.30)   // ✅ Day mode 核心
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        themeManager.isNight
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.08), // ✅ Day mode 用深色边框
                        lineWidth: 1
                    )
            )
            .shadow(
                color: themeManager.isNight
                ? Color.black.opacity(0.15)
                : Color.black.opacity(0.08),       // ✅ 轻微层级
                radius: 10,
                x: 0,
                y: 6
            )
    }
}

extension View {
    func alignaCard() -> some View {
        self.modifier(AlignaCardStyle())
    }
}


struct ProfileView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    // Firestore
    @State private var userDocID: String?
    @State private var userCollectionUsed: String?
    private let db = Firestore.firestore()

    // 当前登录用户
    @State private var email: String = Auth.auth().currentUser?.email ?? ""

    // 用户字段（UI 状态）
    @State private var nickname: String = ""
    @State private var birthday: Date = Date()
    @State private var birthTime: Date = Date()
    @State private var birthPlace: String = ""
    @State private var currentPlace: String = ""
    
    // Birth location & timezone & raw input (for exact display)
    @State private var birthLat: Double = 0
    @State private var birthLng: Double = 0
    @State private var birthTimezoneOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60
    @State private var birthRawTimeString: String? = nil
    @State private var chartSunSign: String = ""
    @State private var chartMoonSign: String = ""
    @State private var chartAscSign: String = ""
    @State private var chartSignature: String = ""
    @State private var hasLoadedProfileData = false


    // 编辑状态
    @State private var editingNickname = false
    @State private var editingBirthPlace = false
    @State private var showBirthdaySheet = false
    @State private var showBirthTimeSheet = false

    // 主题偏好
    @AppStorage("themePreference") private var themePreferenceRaw: String = ThemePreference.auto.rawValue
    @State private var birthPlaceResults: [PlaceResult] = []
    @State private var didSelectBirthPlaceResult = false
    @State private var pendingBirthPlaceCoordinate: CLLocationCoordinate2D?

    // Busy & Error
    @State private var isBusy = false
    @State private var showDeleteAlert = false
    @State private var showReauthPasswordAlert = false
    @State private var reauthPassword = ""
    @State private var errorMessage: String?
    
    
    // 保持定位器存活，避免回调丢失
    @State private var activeLocationFetcher: OneShotLocationFetcher?

    // 刷新结果弹窗
    @State private var showRefreshAlert = false
    @State private var refreshAlertTitle = ""
    @State private var refreshAlertMessage = ""

    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }


    // === 固定英文格式的 Formatter（static，避免 mutating getter 报错）===
    private static let enUSPOSIX = Locale(identifier: "en_US_POSIX")

    private static let birthdayDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "MMM/d/yyyy"
        return f
    }()

    private static let birthTimeDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let birthDateDisplayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = .current
        df.locale   = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let birthTimeStorageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    // 解析兼容：旧的字符串存储
    private static let parseTimeFormatter12: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let parseTimeFormatter24: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let parseDateYYYYMMDD: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let parseDateYMDSlash: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "yyyy/M/d" // 兼容少量 “2024/9/22” 样式
        return f
    }()

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack {
                    AppBackgroundView(nightMotion: .animated)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard
                            personalInfoCard
                            timelineCard
                            themeCard
                            aboutCard
                            signOutCard
                            deleteAccountCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }

                    if isBusy {
                        ProgressView()
                            .scaleEffect(1.1)
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(themeManager.primaryText)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        Spacer()
                    }
                }
                .onAppear {
                    makeNavBarTransparent()
                    themeManager.setSystemColorScheme(colorScheme)
                    if isPreviewMode {
                        applyPreviewDataIfNeeded()
                    } else {
                        initialLoad()
                    }
                }
                .onDisappear { restoreNavBarDefault() }
                .onChange(of: colorScheme) {
                    themeManager.setSystemColorScheme(colorScheme)
                }
            }
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove your profile and all related data. If you signed up with Google or Apple, you may be asked to confirm sign-in one more time before deletion completes.")
        }
        .alert("Confirm Password", isPresented: $showReauthPasswordAlert) {
            SecureField("Password", text: $reauthPassword)
            Button("Cancel", role: .cancel) { reauthPassword = "" }
            Button("Confirm", role: .destructive) { handlePasswordReauthAndDelete() }
        } message: {
            Text("For security reasons, please enter your password to delete your account.")
        }
        .alert("Error",
               isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(refreshAlertTitle, isPresented: $showRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshAlertMessage)
        }

        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    // MARK: - 导航栏透明/恢复
    private func makeNavBarTransparent() {
        let ap = UINavigationBarAppearance()
        ap.configureWithTransparentBackground()
        ap.backgroundEffect = nil
        ap.backgroundColor  = .clear
        ap.shadowColor      = .clear
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = ap
        nav.scrollEdgeAppearance = ap
        nav.compactAppearance = ap
        nav.isTranslucent = true
    }
    private func restoreNavBarDefault() {
        let ap = UINavigationBarAppearance()
        ap.configureWithDefaultBackground()
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = ap
        nav.scrollEdgeAppearance = ap
        nav.compactAppearance = ap
        nav.isTranslucent = false
    }
}

// MARK: - UI Sections
private extension ProfileView {
    var headerCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if editingNickname {
                    TextField("Nickname", text: $nickname)
                        .multilineTextAlignment(.center)
                        .font(.custom("Merriweather-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .tint(themeManager.accent)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    HStack(spacing: 10) {
                        Button {
                            saveField(FSKeys.nickname, value: nickname) {
                                editingNickname = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AlynnaTypography.font(.title2))
                        }

                        Button {
                            editingNickname = false
                            loadUser()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(AlynnaTypography.font(.title2))
                        }
                    }
                    .foregroundColor(themeManager.accent)
                } else {
                    Text(nickname.isEmpty ? "—" : nickname)
                        .font(.custom("Merriweather-Regular", size: 36)) // ✅ 与编辑态完全一致
                        .foregroundColor(themeManager.primaryText)

                    Button { editingNickname = true } label: {
                        Image(systemName: "pencil")
                            .font(AlynnaTypography.font(.title3))
                            .foregroundColor(themeManager.accent)
                    }
                }
            }

            ZodiacInlineRow(
                sunText:  hasLoadedProfileData ? sunSignText : "-",
                moonText: hasLoadedProfileData ? moonSignText : "-",
                ascText:  hasLoadedProfileData ? ascSignText : "-"
            )
            .environmentObject(themeManager)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    var personalInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Information")
                .font(AlynnaTypography.font(.title3)).fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    infoRow(
                        title: "Birthday",
                        value: Self.birthDateDisplayFormatter.string(from: birthday),
                        editable: true
                    ) { showBirthdaySheet = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheet(isPresented: $showBirthdaySheet) {
                        pickerSheet(
                            title: "Birthday",
                            picker: AnyView(
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            ),
                            onSave: {
                                saveBirthDateOnly(newDate: birthday) { showBirthdaySheet = false }
                            },
                            onCancel: { showBirthdaySheet = false }
                        )
                    }

                    infoRow(
                        title: "Birth Time",
                        value: BirthTimeUtils.displayFormatter.string(from: birthTime).lowercased(),
                        editable: true
                    ) { showBirthTimeSheet = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheet(isPresented: $showBirthTimeSheet) {
                        pickerSheet(
                            title: "Birth Time",
                            picker: AnyView(
                                DatePicker("", selection: $birthTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            ),
                            onSave: {
                                saveBirthTimeOnly(newTime: birthTime) { showBirthTimeSheet = false }
                            },
                            onCancel: { showBirthTimeSheet = false }
                        )
                    }
                }

                HStack(spacing: 12) {
                    birthPlaceInfoRow
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheet(isPresented: $editingBirthPlace) {
                        birthPlaceSheet
                    }

                    infoRowWithTrailingButton(
                        title: "Current Place",
                        value: currentPlace.isEmpty ? "—" : currentPlace,
                        systemImage: "arrow.clockwise",
                        onTap: { refreshCurrentPlace() }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .alignaCard()
        }
    }

    var timelineCard: some View {
        NavigationLink {
            TimelineView()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
        } label: {
            rowCard(icon: "calendar", title: "Timeline", subtitle: "View your rhythm journey")
        }
    }

    var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundColor(themeManager.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Theme")
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                    Text("Customize appearance")
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText)
                }
            }
            HStack(spacing: 12) { themeOption(.light); themeOption(.dark); themeOption(.auto) }
        }
        .padding()
        .alignaCard()
    }

    var aboutCard: some View {
        NavigationLink {
            AboutView()
        } label: {
            rowCard(
                icon: "info.circle",
                title: "About",
                subtitle: "More about the app & privacy"
            )
        }
    }

    var signOutCard: some View {
        Button {
            do {
                try signOutCurrentSession()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            rowCard(icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign out",
                    subtitle: "Sign out of your account")
        }
    }

    var deleteAccountCard: some View {
        Button(role: .destructive) { showDeleteAlert = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.red.opacity(themeManager.isNight ? 0.92 : 0.78))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Danger Zone")
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(Color.red.opacity(themeManager.isNight ? 0.92 : 0.78))

                    Text("Permanently delete your account")
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Color.red.opacity(themeManager.isNight ? 0.90 : 0.70))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                Color.red.opacity(themeManager.isNight ? 0.22 : 0.14),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.red.opacity(themeManager.isNight ? 0.55 : 0.35), lineWidth: 1)
            )
        }
    }

    var astrologyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Astrology (approximate)")
                .font(AlynnaTypography.font(.title3)).fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sun sign")
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.descriptionText)
                        Text(sunSignText)
                            .font(AlynnaTypography.font(.headline))
                            .foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Moon sign")
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.descriptionText)
                        Text(moonSignText)
                            .font(AlynnaTypography.font(.headline))
                            .foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ascendant")
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.descriptionText)
                        Text(ascSignText)
                            .font(AlynnaTypography.font(.headline))
                            .foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                Text("Note: Lightweight astronomical approximations; values near sign cusps may vary slightly.")
                    .font(AlynnaTypography.font(.footnote))
                    .foregroundColor(themeManager.descriptionText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.white.opacity(themeManager.isNight ? 0.05 : 0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                                Color.white.opacity(
                                    themeManager.isNight ? 0.10 : 0.22
                                ),
                                lineWidth: 1
                            )
            )
        }
    }
}

// MARK: - Reusable UI
private extension ProfileView {

    func rowCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(themeManager.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AlynnaTypography.font(.headline))
                    .foregroundColor(themeManager.primaryText)

                Text(subtitle)
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.descriptionText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(themeManager.primaryText.opacity(0.9))
        }
        .padding()


        .frame(maxWidth: .infinity)
        .alignaCard()
    }

    func infoRow(title: String, value: String, editable: Bool, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(AlynnaTypography.font(.footnote))
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 + 小笔 靠在一起
            HStack(spacing: 6) {
                Text(value)
                    .font(AlynnaTypography.font(.headline))
                    .foregroundColor(themeManager.primaryText)

                if editable {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(AlynnaTypography.font(.body))
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 6)
    }

    func infoRowWithTrailingButton(
        title: String,
        value: String,
        systemImage: String,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(AlynnaTypography.font(.footnote))
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 + 按钮 靠在一起
            HStack(spacing: 6) {
                Text(value)
                    .font(AlynnaTypography.font(.headline))
                    .foregroundColor(themeManager.primaryText)

                Button(action: onTap) {
                    Image(systemName: systemImage)
                        .font(AlynnaTypography.font(.body))
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Refresh \(title)"))

                Spacer(minLength: 0) // 可要可不要，留一点弹性空间
            }
        }
        .padding(.vertical, 6)
    }

    func infoRowEditableText(
        title: String,
        text: Binding<String>,
        isEditing: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(AlynnaTypography.font(.footnote))
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 / TextField + 图标 靠在一起
            HStack(spacing: 6) {
                if isEditing.wrappedValue {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .tint(themeManager.accent)
                        .foregroundColor(themeManager.primaryText)
                        .font(AlynnaTypography.font(.headline))
                } else {
                    Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                }

                if isEditing.wrappedValue {
                    HStack(spacing: 10) {
                        Button(action: onSave) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AlynnaTypography.font(.title3))
                        }
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(AlynnaTypography.font(.title3))
                        }
                    }
                    .foregroundColor(themeManager.accent)
                } else {
                    Button { isEditing.wrappedValue = true } label: {
                        Image(systemName: "pencil")
                            .font(AlynnaTypography.font(.body))
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 6)
    }

    var birthPlaceInfoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Birth Place")
                .font(AlynnaTypography.font(.footnote))
                .foregroundColor(themeManager.descriptionText)

            birthPlaceDisplayContent
        }
        .padding(.vertical, 6)
    }

    var birthPlaceSheet: some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(themeManager.descriptionText.opacity(0.35))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Select Birth Place")
                    .font(AlynnaTypography.font(.title3))
                    .foregroundColor(themeManager.primaryText)
                Text("Search and choose a location to update your birth coordinates.")
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.descriptionText)
            }

            TextField("Birth Place", text: $birthPlace)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .tint(themeManager.accent)
                .foregroundColor(themeManager.primaryText)
                .font(AlynnaTypography.font(.headline))
                .onChange(of: birthPlace) { _, newValue in
                    if didSelectBirthPlaceResult {
                        didSelectBirthPlaceResult = false
                        return
                    }

                    pendingBirthPlaceCoordinate = nil

                    let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !query.isEmpty else {
                        birthPlaceResults = []
                        return
                    }
                    performBirthPlaceSearch(query: query)
                }

            if !birthPlaceResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(birthPlaceResults.prefix(4)), id: \.id) { result in
                        birthPlaceResultButton(for: result)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: saveBirthPlaceSelection) {
                    Text("Save")
                        .font(AlynnaTypography.font(.body))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accent.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: cancelBirthPlaceEditing) {
                    Text("Cancel")
                        .font(AlynnaTypography.font(.body))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.panelFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .foregroundColor(themeManager.accent)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .preferredColorScheme(themeManager.preferredColorScheme)
        .presentationDetents([.fraction(0.48), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.ultraThinMaterial)
    }

    var birthPlaceDisplayContent: some View {
        HStack(spacing: 6) {
            Text(birthPlace.isEmpty ? "—" : birthPlace)
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.primaryText)

            Button {
                pendingBirthPlaceCoordinate = CLLocationCoordinate2D(latitude: birthLat, longitude: birthLng)
                birthPlaceResults = []
                editingBirthPlace = true
            } label: {
                Image(systemName: "pencil")
                    .font(AlynnaTypography.font(.body))
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.accent)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    func birthPlaceResultButton(for result: PlaceResult) -> some View {
        Button {
            birthPlace = result.name
            pendingBirthPlaceCoordinate = result.coordinate
            birthPlaceResults = []
            didSelectBirthPlaceResult = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.primaryText)
                Text(result.subtitle)
                    .font(AlynnaTypography.font(.caption1))
                    .foregroundColor(themeManager.descriptionText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(themeManager.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(themeManager.panelStrokeHi, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func themeOption(_ pref: ThemePreference) -> some View {
        let selected = themePreferenceRaw == pref.rawValue
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                themePreferenceRaw = pref.rawValue
                switch pref {
                case .light: themeManager.selected = .day
                case .dark:  themeManager.selected = .night
                case .auto:  themeManager.selected = .system
                }
                themeManager.setSystemColorScheme(colorScheme)
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: pref.icon)
                    .font(AlynnaTypography.font(.title2))

                Text(pref.title)
                    .font(AlynnaTypography.font(.subheadline))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? themeManager.accent.opacity(0.18)
                                  : Color.white.opacity(themeManager.isNight ? 0.06 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? themeManager.accent : Color.white.opacity(0.15),
                            lineWidth: selected ? 1 : 0.8)
            )
            .foregroundColor(selected ? themeManager.accent : themeManager.primaryText)
        }
        .buttonStyle(.plain)
    }

    /// Map "Aries" -> "aries", "Taurus" -> "taurus", ... for SF Symbols.
    /// If not found, fall back to "questionmark.circle".
    func zodiacSFIcon(for signName: String) -> String {
        switch signName.lowercased() {
        case "aries": return "aries"
        case "taurus": return "taurus"
        case "gemini": return "gemini"
        case "cancer": return "cancer"
        case "leo": return "leo"
        case "virgo": return "virgo"
        case "libra": return "libra"
        case "scorpio": return "scorpio"
        case "sagittarius": return "sagittarius"
        case "capricorn": return "capricorn"
        case "aquarius": return "aquarius"
        case "pisces": return "pisces"
        default: return "questionmark.circle"
        }
    }

    /// A compact pill with a kind icon (sun/moon/asc) + the zodiac glyph + text value.
    func zodiacPill(title: String, systemImage: String, signImage: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(AlynnaTypography.font(.caption2))
                .fontWeight(.semibold)

            Image(systemName: signImage)
                .font(AlynnaTypography.font(.caption2))
                .fontWeight(.semibold)

            Text(title)
                .font(AlynnaTypography.font(.caption2))
                .fontWeight(.semibold)

            Text(value)
                .font(AlynnaTypography.font(.caption1))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(themeManager.isNight ? 0.06 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(themeManager.isNight ? 0.1 : 0.08), lineWidth: 0.8)
        )
        .foregroundColor(themeManager.primaryText)
    }

    @ViewBuilder
    func pickerSheet(
        title: String,
        picker: AnyView,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.primaryText)

            picker.tint(themeManager.accent)

            HStack {
                Button("Cancel", action: onCancel)
                    .font(AlynnaTypography.font(.body))
                Spacer()
                Button("Save", action: onSave)
                    .font(AlynnaTypography.font(.body))
            }
            .foregroundColor(themeManager.accent)
            .padding(.horizontal)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .presentationDetents([.height(320)])
        .presentationBackground(.ultraThinMaterial)
    }

    // ✅ 下面这些不是 UI 字体相关，不需要改动
    final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
        private let manager = CLLocationManager()
        private var callback: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

        override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }

        func requestOnce(_ cb: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
            self.callback = cb
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                cb(.failure(NSError(domain: "Aligna", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Location permission denied."])))
            default:
                manager.requestLocation()
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.first else {
                callback?(.failure(NSError(domain: "Aligna", code: 2,
                                           userInfo: [NSLocalizedDescriptionKey: "No location found."])))
                callback = nil
                return
            }
            callback?(.success(loc.coordinate)); callback = nil
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            callback?(.failure(error)); callback = nil
        }
    }

    func refreshCurrentPlace() {
        // 防抖：忙时不再进入
        if isBusy { return }

        isBusy = true
        errorMessage = nil

        let previous = self.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)

        // 10 秒看门狗，防止永久 loading
        var timedOut = false
        let watchdog = DispatchWorkItem {
            timedOut = true
            self.isBusy = false
            self.activeLocationFetcher = nil
            self.refreshAlertTitle = "Location Timeout"
            self.refreshAlertMessage = "Exceed 10 seconds, please try again."
            self.showRefreshAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: watchdog)

        // 持有引用，确保回调能触发
        let fetcher = OneShotLocationFetcher()
        self.activeLocationFetcher = fetcher

        fetcher.requestOnce { result in
            // 任一回调路径都先清理看门狗
            DispatchQueue.main.async {
                if !watchdog.isCancelled { watchdog.cancel() }
            }

            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    guard !timedOut else { return } // 已经被看门狗处理
                    self.isBusy = false
                    self.activeLocationFetcher = nil
                    self.refreshAlertTitle = "Location Error"
                    self.refreshAlertMessage = err.localizedDescription
                    self.showRefreshAlert = true
                }

            case .success(let coord):
                // 逆地理
                getAddressFromCoordinate(coord) { maybeCity in
                    DispatchQueue.main.async {
                        guard !timedOut else { return }

                        let city = (maybeCity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let placeToShow = city.isEmpty
                            ? String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                            : city

                        // 更新 UI
                        self.currentPlace = placeToShow

                        // 写入 Firestore（即使没变也写：更新坐标 & 时间戳）
                        let payload: [String: Any] = [
                            FSKeys.currentPlace: placeToShow,
                            "currentLat": coord.latitude,
                            "currentLng": coord.longitude,
                            "updatedAt": FieldValue.serverTimestamp()
                        ]
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastCurrentPlaceUpdate")

                        func finishAndAlert() {
                            self.isBusy = false
                            self.activeLocationFetcher = nil

                            // 比较是否变化（大小写与首尾空格忽略）
                            let changed = previous.lowercased() != placeToShow.lowercased()

                            if changed {
                                self.refreshAlertTitle = "Location Updated"
                                self.refreshAlertMessage = "Updated to：\(placeToShow)"
                            } else {
                                self.refreshAlertTitle = "Location unchanged.（Still at：\(placeToShow)）"
                            }
                            self.showRefreshAlert = true
                        }

                        if let col = self.userCollectionUsed, let id = self.userDocID {
                            self.db.collection(col).document(id).setData(payload, merge: true) { err in
                                if let err = err {
                                    // 写库失败也要结束 loading，并提示
                                    self.isBusy = false
                                    self.activeLocationFetcher = nil
                                    self.refreshAlertTitle = "Save Failed"
                                    self.refreshAlertMessage = err.localizedDescription
                                    self.showRefreshAlert = true
                                } else {
                                    finishAndAlert()
                                }
                            }
                        } else {
                            // 尚未载入用户文档：仍然结束并提示
                            finishAndAlert()
                        }
                    }
                }
            }
        }
    }
}

// About page

// === One-shot 定位器 ===



// MARK: - Data & Actions
private extension ProfileView {
    func applyPreviewDataIfNeeded() {
        guard nickname.isEmpty, email.isEmpty else { return }

        email = "hello@aligna.app"
        nickname = "Luna"
        birthday = Calendar.current.date(from: DateComponents(year: 1996, month: 3, day: 14)) ?? Date()
        birthTime = BirthTimeUtils.makeLocalTimeDate(hour: 7, minute: 42)
        birthPlace = "Hangzhou, China"
        currentPlace = "San Francisco, CA"
        chartSunSign = "Pisces"
        chartMoonSign = "Libra"
        chartAscSign = "Gemini"
        chartSignature = "Pisces-Libra-Gemini"
        birthRawTimeString = "7:42 AM"
        birthTimezoneOffsetMinutes = 480
        userDocID = "preview-user"
        userCollectionUsed = FSKeys.userPrimary
        isBusy = false
        errorMessage = nil
    }

    func initialLoad() {
        switch ThemePreference(rawValue: themePreferenceRaw) ?? .auto {
        case .light: themeManager.selected = .day
        case .dark:  themeManager.selected = .night
        case .auto:  themeManager.selected = .system
        }
        themeManager.setSystemColorScheme(colorScheme)
        loadUser()
    }

    private var candidateUserCollections: [String] { [FSKeys.userPrimary, FSKeys.userAlt] }

    func loadUser() {
        guard let user = Auth.auth().currentUser else { return }
        isBusy = true
        hasLoadedProfileData = false
        errorMessage = nil

        queryByUID(user.uid) { doc, col in
            if let doc = doc, let col = col {
                applyUserDoc(doc, in: col); isBusy = false; return
            }
            if let em = user.email {
                self.email = em
                queryByEmail(em) { doc2, col2 in
                    if let doc2 = doc2, let col2 = col2 {
                        applyUserDoc(doc2, in: col2)
                    } else {
                        self.errorMessage = "No user profile found for \(em)."
                    }
                    isBusy = false
                }
            } else {
                self.errorMessage = "No user profile for current account."
                isBusy = false
            }
        }
    }

    private func queryByUID(_ uid: String, completion: @escaping (DocumentSnapshot?, String?) -> Void) {
        queryInCollections { ref in
            ref.whereField(FSKeys.uid, isEqualTo: uid).limit(to: 1)
        } completion: { doc, col in completion(doc, col) }
    }

    private func queryByEmail(_ email: String, completion: @escaping (DocumentSnapshot?, String?) -> Void) {
        queryInCollections { ref in
            ref.whereField(FSKeys.email, isEqualTo: email).limit(to: 1)
        } completion: { doc, col in completion(doc, col) }
    }

    private func queryInCollections(
        where makeQuery: @escaping (CollectionReference) -> Query,
        completion: @escaping (DocumentSnapshot?, String?) -> Void
    ) {
        func go(_ i: Int) {
            if i >= candidateUserCollections.count { completion(nil, nil); return }
            let col = candidateUserCollections[i]
            makeQuery(db.collection(col)).getDocuments { snap, _ in
                if let doc = snap?.documents.first { completion(doc, col) }
                else { go(i + 1) }
            }
        }
        go(0)
    }

    func applyUserDoc(_ doc: DocumentSnapshot, in collection: String) {
        self.userDocID = doc.documentID
        self.userCollectionUsed = collection
        let data = doc.data() ?? [:]

        self.nickname = data[FSKeys.nickname] as? String ?? ""

        // birthday：优先 Timestamp；其次你旧的 "birthDate" 字符串（yyyy-MM-dd / yyyy/M/d）
        if let ts = data[FSKeys.birthday] as? Timestamp {
            self.birthday = ts.dateValue()
        } else if let s = data["birthDate"] as? String {
            if let d = Self.parseDateYYYYMMDD.date(from: s) {
                self.birthday = d
            } else if let d2 = Self.parseDateYMDSlash.date(from: s) {
                self.birthday = d2
            }
        }

        // birthTime：首选新的 birthHour/birthMinute；兼容旧的 "birthTime" 字符串
        var hour: Int? = data["birthHour"] as? Int
        var minute: Int? = data["birthMinute"] as? Int

        if hour == nil || minute == nil {
            if let t = data[FSKeys.birthTime] as? String, let d = timeToDate(t) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                hour = hour ?? comps.hour
                minute = minute ?? comps.minute
            }
        }
        self.birthTime = BirthTimeUtils.makeLocalTimeDate(hour: hour ?? 0, minute: minute ?? 0)

        self.birthPlace   = data[FSKeys.birthPlace] as? String ?? ""
        self.currentPlace = (data[FSKeys.currentPlace] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // --- 修正 currentPlace（保持你原逻辑） ---
        let needsFix: Bool = {
            if currentPlace.isEmpty { return true }
            if currentPlace.lowercased() == "unknown" { return true }
            if isCoordinateLikeString(currentPlace) { return true }
            return false
        }()

        if needsFix,
           let lat = data["currentLat"] as? CLLocationDegrees,
           let lng = data["currentLng"] as? CLLocationDegrees {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            getAddressFromCoordinate(coord) { resolved in
                guard let city = resolved, !city.isEmpty else { return }
                DispatchQueue.main.async {
                    self.currentPlace = city
                    self.saveField(FSKeys.currentPlace, value: city) { }
                }
            }
        }

        // --- Birth geo & timezone & raw time（保持你的兼容逻辑） ---
        if let lat = data["birthLat"] as? CLLocationDegrees { self.birthLat = lat }
        else if let lat = data["birth_lat"] as? CLLocationDegrees { self.birthLat = lat }

        if let lng = data["birthLng"] as? CLLocationDegrees { self.birthLng = lng }
        else if let lng = data["birth_lng"] as? CLLocationDegrees { self.birthLng = lng }

        if let tzMin = data["birthTimezoneOffsetMinutes"] as? Int {
            self.birthTimezoneOffsetMinutes = tzMin
        } else if let tzMin = data["timezoneOffsetMinutes"] as? Int {
            self.birthTimezoneOffsetMinutes = tzMin
        } else {
            self.birthTimezoneOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        }

        if let raw = data["birthTimeRaw"] as? String {
            self.birthRawTimeString = raw
        } else if let raw = data["birth_raw"] as? String {
            self.birthRawTimeString = raw
        } else if let raw = data["birthTimeOriginal"] as? String {
            self.birthRawTimeString = raw
        } else {
            self.birthRawTimeString = nil
        }

        self.pendingBirthPlaceCoordinate = CLLocationCoordinate2D(latitude: birthLat, longitude: birthLng)
        self.birthPlaceResults = []
        self.didSelectBirthPlaceResult = false
        hasLoadedProfileData = true
        clearChartData()
        syncChartDataIfNeeded()
    }


    func saveField<T>(_ key: String, value: T, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true
        db.collection(col).document(id).setData([key: value], merge: true) { err in
            isBusy = false
            if let err = err { errorMessage = err.localizedDescription } else { completion() }
        }
    }
    // 统一保存（向后兼容旧字段）
    // === Replace the old saveBirthFields with two explicit flows ===

    // 仅更新“生日”部分（日期），并与当前“时间”合并后写库
    // 仅更新“生日”（日期）
    func saveBirthDateOnly(newDate: Date, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true

        let dateStr = Self.parseDateYYYYMMDD.string(from: newDate) // "yyyy-MM-dd"

        let payload: [String: Any] = [
            FSKeys.birthday: Timestamp(date: newDate), // 正式字段（仅日期语义）
            "birth_date": dateStr,                     // 兼容旧字段
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(col).document(id).setData(payload, merge: true) { err in
            self.isBusy = false
            if let err = err { self.errorMessage = err.localizedDescription; return }
            self.birthday = newDate   // 本地状态只改日期
            self.syncChartDataIfNeeded(force: true, completion: completion)
        }
    }

    // 仅更新时间（时:分）
    func saveBirthTimeOnly(newTime: Date, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true

        let (h, m) = BirthTimeUtils.hourMinute(from: newTime)

        // 兼容：写一个 "HH:mm" 字符串，方便旧逻辑或后端使用
        let time24: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "HH:mm"
            return f.string(from: newTime)
        }()

        let timeRaw = BirthTimeUtils.displayFormatter.string(from: newTime).lowercased()

        let payload: [String: Any] = [
            "birthHour": h,
            "birthMinute": m,
            "birth_time": time24,            // 兼容旧字段
            "birthTimeRaw": timeRaw,         // 显示方便
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(col).document(id).setData(payload, merge: true) { err in
            self.isBusy = false
            if let err = err { self.errorMessage = err.localizedDescription; return }
            // 本地状态只改“时间”
            self.birthTime = BirthTimeUtils.makeLocalTimeDate(hour: h, minute: m)
            self.birthRawTimeString = timeRaw
            self.syncChartDataIfNeeded(force: true, completion: completion)
        }
    }

    func saveBirthPlaceSelection() {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."
            return
        }

        let placeName = birthPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !placeName.isEmpty else {
            errorMessage = "Birth place cannot be empty."
            return
        }

        guard let coordinate = pendingBirthPlaceCoordinate else {
            errorMessage = "Please select a birth place from the search results."
            return
        }

        isBusy = true

        let payload: [String: Any] = [
            FSKeys.birthPlace: placeName,
            "birthLat": coordinate.latitude,
            "birthLng": coordinate.longitude,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(col).document(id).setData(payload, merge: true) { err in
            self.isBusy = false
            if let err = err {
                self.errorMessage = err.localizedDescription
                return
            }

            self.birthPlace = placeName
            self.birthLat = coordinate.latitude
            self.birthLng = coordinate.longitude
            self.editingBirthPlace = false
            self.birthPlaceResults = []
            self.didSelectBirthPlaceResult = false
            self.syncChartDataIfNeeded(force: true)
        }
    }

    func cancelBirthPlaceEditing() {
        editingBirthPlace = false
        birthPlaceResults = []
        didSelectBirthPlaceResult = false
        pendingBirthPlaceCoordinate = nil
        loadUser()
    }

    func performBirthPlaceSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        MKLocalSearch(request: request).start { response, _ in
            let results = response?.mapItems.compactMap { item in
                PlaceResult(
                    name: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            } ?? []

            DispatchQueue.main.async {
                if self.birthPlace.trimmingCharacters(in: .whitespacesAndNewlines) == query {
                    self.birthPlaceResults = results
                }
            }
        }
    }

    private func applyChartData(from data: [String: Any]) {
        guard let chartData = data["chartData"] as? [String: Any] else {
            clearChartData()
            return
        }

        chartSunSign = (chartData["sun"] as? String ?? chartData["sunSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        chartMoonSign = (chartData["moon"] as? String ?? chartData["moonSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        chartAscSign = (chartData["ascendant"] as? String ?? chartData["ascendantSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        chartSignature = (data["signature"] as? String ?? chartData["signature"] as? String ?? "")
    }

    private func clearChartData() {
        chartSunSign = ""
        chartMoonSign = ""
        chartAscSign = ""
        chartSignature = ""
    }

    private func syncChartDataIfNeeded(force: Bool = false, completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?()
            return
        }

        let signature = chartComputationSignature

        if force {
            refreshChartDataFromAPI(uid: uid, signature: signature, completion: completion)
        } else {
            loadStoredChartData(uid: uid, expectedSignature: signature, completion: completion)
        }
    }

    private func loadStoredChartData(uid: String, expectedSignature: String, completion: (() -> Void)? = nil) {
        db.collection(FSKeys.chartData).document(uid).getDocument { snap, err in
            if let err = err {
                self.errorMessage = err.localizedDescription
                self.refreshChartDataFromAPI(uid: uid, signature: expectedSignature, completion: completion)
                return
            }

            let data = snap?.data() ?? [:]
            let storedSignature = data["signature"] as? String ?? ""
            let hasStoredChart = (data["chartData"] as? [String: Any]) != nil

            if hasStoredChart && storedSignature == expectedSignature {
                self.applyChartData(from: data)
                completion?()
                return
            }

            self.refreshChartDataFromAPI(uid: uid, signature: expectedSignature, completion: completion)
        }
    }

    private func refreshChartDataFromAPI(uid: String, signature: String, completion: (() -> Void)? = nil) {
        let birthDateString = Self.parseDateYYYYMMDD.string(from: birthday)
        let birthTimeString = Self.birthTimeStorageFormatter.string(from: birthTime)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": birthLat,
            "longitude": birthLng
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/chart/") else {
            errorMessage = "Invalid chart API URL."
            completion?()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            errorMessage = error.localizedDescription
            completion?()
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, err in
            if let err = err {
                DispatchQueue.main.async {
                    self.errorMessage = err.localizedDescription
                    completion?()
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "Chart API returned no data."
                    completion?()
                }
                return
            }

            do {
                guard let chartResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Invalid chart API response."
                        completion?()
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.saveChartData(uid: uid, chartResponse: chartResponse, signature: signature, completion: completion)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion?()
                }
            }
        }.resume()
    }

    private func saveChartData(
        uid: String,
        chartResponse: [String: Any],
        signature: String,
        completion: (() -> Void)? = nil
    ) {
        let document: [String: Any] = [
            "uid": uid,
            "signature": signature,
            "chartData": chartResponse,
            "source": "api",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(FSKeys.chartData).document(uid).setData(document, merge: true) { err in
            if let err = err {
                self.errorMessage = err.localizedDescription
                completion?()
                return
            }

            self.db.collection(FSKeys.chartData).document(uid).getDocument { snap, fetchErr in
                if let fetchErr = fetchErr {
                    self.errorMessage = fetchErr.localizedDescription
                    self.applyChartData(from: document)
                    completion?()
                    return
                }

                self.applyChartData(from: snap?.data() ?? document)
                completion?()
            }
        }
    }


    // 合并“日期部分”和“时间部分”
    func merge(datePart: Date, timePart: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Self.enUSPOSIX
        cal.timeZone = .current
        let d = cal.dateComponents([.year, .month, .day], from: datePart)
        let t = cal.dateComponents([.hour, .minute, .second], from: timePart)
        var comp = DateComponents()
        comp.year = d.year
        comp.month = d.month
        comp.day = d.day
        comp.hour = t.hour
        comp.minute = t.minute
        comp.second = t.second ?? 0
        return cal.date(from: comp) ?? datePart
    }

    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        if isPasswordProvider(user) {
            showReauthPasswordAlert = true
            return
        }
        startDeleteFlow(allowPasswordBypass: false)
    }

    func handlePasswordReauthAndDelete() {
        let password = reauthPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }
        isBusy = true
        errorMessage = nil
        reauthenticateWithPassword(password) { err in
            self.isBusy = false
            if let err = err {
                self.errorMessage = err.localizedDescription
                return
            }
            self.reauthPassword = ""
            self.startDeleteFlow(allowPasswordBypass: true)
        }
    }

    private func startDeleteFlow(allowPasswordBypass: Bool) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let email = user.email
        isBusy = true
        errorMessage = nil
        ensureRecentLoginForDeletion(allowPasswordBypass: allowPasswordBypass) { recentLoginErr in
            if let recentLoginErr = recentLoginErr as NSError? {
                self.isBusy = false
                if self.isUserCancelledSignIn(recentLoginErr) {
                    return
                }
                if recentLoginErr.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    self.errorMessage = "For security reasons, please sign in again, then retry deletion."
                } else {
                    self.errorMessage = recentLoginErr.localizedDescription
                }
                return
            }

            self.purgeAllUserData(uid: uid, email: email) { purgeErr in
                if let purgeErr = purgeErr {
                    self.isBusy = false
                    self.errorMessage = "Delete failed (data purge): \(purgeErr.localizedDescription)"
                    return
                }
                self.deleteAuthAccount(allowReauthentication: false) { authErr in
                    self.isBusy = false
                    if let e = authErr as NSError? {
                        if e.code == AuthErrorCode.requiresRecentLogin.rawValue {
                            self.errorMessage = "For security reasons, please sign in again, then retry deletion."
                        } else {
                            self.errorMessage = "Account deletion failed: \(e.localizedDescription)"
                        }
                        return
                    }
                    clearLocalStateAfterAccountDeletion()
                    self.dismiss()
                }
            }
        }
    }

    private func isPasswordProvider(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == "password" }
    }

    private func reauthenticateWithPassword(_ password: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(nil); return }
        guard let email = user.email else {
            completion(NSError(domain: "Aligna", code: -6, userInfo: [NSLocalizedDescriptionKey: "Missing email for password reauthentication."]))
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { _, err in completion(err) }
    }
    func purgeCollection(
            _ name: String,
            whereField field: String,
            equals value: Any,
            batchSize: Int = 400,
            completion: @escaping (Error?) -> Void
        ) {
            let q = db.collection(name).whereField(field, isEqualTo: value).limit(to: batchSize)
            q.getDocuments { snap, err in
                if let err = err { completion(err); return }
                let docs = snap?.documents ?? []
                if docs.isEmpty { completion(nil); return }

                let batch = self.db.batch()
                docs.forEach { batch.deleteDocument($0.reference) }
                batch.commit { err in
                    if let err = err { completion(err); return }
                    // 继续删下一页
                    self.purgeCollection(name, whereField: field, equals: value, batchSize: batchSize, completion: completion)
                }
            }
        }

        // --- 多条件并行（uid / email） ---
        func purgeCollectionByFields(
            _ name: String,
            fieldsAndValues: [(String, Any)],
            completion: @escaping (Error?) -> Void
        ) {
            let group = DispatchGroup()
            var firstErr: Error?

            for (f, v) in fieldsAndValues {
                group.enter()
                purgeCollection(name, whereField: f, equals: v) { err in
                    if let err = err, firstErr == nil { firstErr = err }
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion(firstErr) }
        }
    func purgeAllUserData(uid: String, email: String?, completion: @escaping (Error?) -> Void) {
            let group = DispatchGroup()
            var firstErr: Error?

            func record(_ err: Error?) {
                if let err = err, firstErr == nil { firstErr = err }
            }

            // A) 用户档案：users / user
            let userCols = ["users", "user"]
            for col in userCols {
                group.enter()
                var pairs: [(String, Any)] = [("uid", uid)]
                if let em = email, !em.isEmpty { pairs.append(("email", em)) }
                purgeCollectionByFields(col, fieldsAndValues: pairs) { err in
                    record(err); group.leave()
                }
            }

            // B) 日推荐：兼容 4 种集合名
            let recCols = ["daily_recommendation", "daily recommendation", "daily_recommendations", "dailyRecommendations"]
            for col in recCols {
                // B1) 按字段删（uid / 兼容旧 email）
                group.enter()
                var pairs: [(String, Any)] = [("uid", uid)]
                if let em = email, !em.isEmpty { pairs.append(("email", em)) }
                purgeCollectionByFields(col, fieldsAndValues: pairs) { err in
                    record(err); group.leave()
                }

                // B2) 追加按文档ID前缀删（历史数据可能没有 uid 字段）
                group.enter()
                purgeByDocIDPrefix(col, prefix: uid + "_") { err in
                    record(err); group.leave()
                }
                if let em = email, !em.isEmpty {
                    group.enter()
                    purgeByDocIDPrefix(col, prefix: em + "_") { err in
                        record(err); group.leave()
                    }
                }
            }

            // C) 单文档派生数据
            let singleDocCollections = [FSKeys.chartData]
            for col in singleDocCollections {
                group.enter()
                db.collection(col).document(uid).delete { err in
                    record(err); group.leave()
                }
            }

            group.notify(queue: .main) { completion(firstErr) }
        }
    func purgeByDocIDPrefix(
            _ name: String,
            prefix: String,
            batchSize: Int = 400,
            completion: @escaping (Error?) -> Void
        ) {
            guard !prefix.isEmpty else { completion(nil); return }
            // Firestore 的“前缀查询”技巧： [prefix, prefix+\u{f8ff}]
            let start = prefix
            let end   = prefix + "\u{f8ff}"

            let q = db.collection(name)
                .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: start)
                .whereField(FieldPath.documentID(), isLessThanOrEqualTo: end)
                .limit(to: batchSize)

            q.getDocuments { snap, err in
                if let err = err { completion(err); return }
                let docs = snap?.documents ?? []
                if docs.isEmpty { completion(nil); return }

                let batch = self.db.batch()
                docs.forEach { batch.deleteDocument($0.reference) }
                batch.commit { err in
                    if let err = err { completion(err); return }
                    // 继续删下一页
                    self.purgeByDocIDPrefix(name, prefix: prefix, batchSize: batchSize, completion: completion)
                }
            }
        }

    func ensureRecentLoginForDeletion(allowPasswordBypass: Bool = false, completion: @escaping (Error?) -> Void) {
            guard let user = Auth.auth().currentUser else { completion(nil); return }
            let providerIDs = user.providerData.map { $0.providerID }

            if providerIDs.contains("password") {
                if allowPasswordBypass {
                    completion(nil)
                } else {
                    completion(NSError(
                        domain: "Aligna",
                        code: Int(AuthErrorCode.requiresRecentLogin.rawValue),
                        userInfo: [NSLocalizedDescriptionKey: "Please sign in again with email & password, then delete."]
                    ))
                }
                return
            }

            reauthenticateCurrentUser(completion: completion)
        }

    func deleteAuthAccount(allowReauthentication: Bool = true, completion: @escaping (Error?) -> Void) {
            guard let user = Auth.auth().currentUser else { completion(nil); return }
            user.delete { err in
                if let e = err as NSError?,
                   e.code == AuthErrorCode.requiresRecentLogin.rawValue,
                   allowReauthentication {
                    // 需要最近登录 → 自动 reauth 后重试
                    self.reauthenticateCurrentUser { reErr in
                        if let reErr = reErr { completion(reErr); return }
                        Auth.auth().currentUser?.delete { secondErr in
                            completion(secondErr)
                        }
                    }
                } else {
                    completion(err)
                }
            }
        }
    func reauthenticateCurrentUser(completion: @escaping (Error?) -> Void) {
            guard let user = Auth.auth().currentUser else { completion(nil); return }

            // 找到优先可用的 provider
            let providerIDs = user.providerData.map { $0.providerID } // e.g., "google.com", "apple.com", "password"
            guard let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
                completion(NSError(domain: "Aligna", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller."]))
                return
            }

            if providerIDs.contains("google.com") {
                reauthWithGoogle(presenting: rootVC, completion: completion)
            } else if providerIDs.contains("apple.com") {
                reauthWithApple(presenting: rootVC, completion: completion)
            } else if providerIDs.contains("password") {
                completion(NSError(domain: "Aligna", code: Int(AuthErrorCode.requiresRecentLogin.rawValue),
                                   userInfo: [NSLocalizedDescriptionKey: "Please sign in again with email & password, then delete."]))
            } else {
                completion(NSError(domain: "Aligna", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider."]))
            }
        }
    func reauthWithGoogle(presenting rootVC: UIViewController, completion: @escaping (Error?) -> Void) {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                completion(NSError(domain: "Aligna", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID."]))
                return
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            // 直接触发一次 Google 登录获取新 token
            GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
                if let error = error { completion(error); return }
                guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                    completion(NSError(domain: "Aligna", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing Google token."]))
                    return
                }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                Auth.auth().currentUser?.reauthenticate(with: credential) { _, err in completion(err) }
            }
        }

        // --- Apple 重新验证 ---
        func reauthWithApple(presenting rootVC: UIViewController, completion: @escaping (Error?) -> Void) {
            let nonce = randomNonceString()
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [] // 只需要 token，不需要姓名/邮箱
            request.nonce = sha256(nonce)

            let coordinator = AppleReauthCoordinator(nonce: nonce) { token, err in
                if let err = err { completion(err); return }
                guard let token = token, let tokenStr = String(data: token, encoding: .utf8) else {
                    completion(NSError(domain: "Aligna", code: -5, userInfo: [NSLocalizedDescriptionKey: "Missing Apple token."]))
                    return
                }
                let credential = OAuthProvider.credential(providerID: .apple, idToken: tokenStr, rawNonce: nonce)
                Auth.auth().currentUser?.reauthenticate(with: credential) { _, err in completion(err) }
            }

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            coordinator.presentingWindow = rootVC.view.window
            controller.performRequests()
        }

    func clearLocalStateAfterAccountDeletion() {
        // 1) 清空本地标记（避免冷启动误判）
        clearLocalAuthFlags()
        UserDefaults.standard.set(true, forKey: "didDeleteAccount")

        // 2) Firebase sign out（双保险：就算 user.delete 成功，也显式登出一次）
        try? Auth.auth().signOut()

        // 3) 断开 Google 会话（防止“静默恢复”导致下次进入就是已登录态）
        GIDSignIn.sharedInstance.disconnect { error in
            if let e = error { print("⚠️ Google disconnect failed: \(e)") }
            else { print("✅ Google session disconnected") }
        }

        NotificationCenter.default.post(name: .didDeleteAccount, object: nil)
    }

    private func isUserCancelledSignIn(_ error: NSError) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("cancel") || text.contains("canceled") || text.contains("cancelled")
    }
    
    // ===== Astrology glue (no extra conversion) =====

    // Merge local civil date & time (your existing helper already uses .current)
    private var mergedLocalBirthDateTime: Date {
        merge(datePart: birthday, timePart: birthTime)
    }

    // BirthInfo used for display (keeps the local civil time; NO second conversion)
    private var birthInfo: BirthInfo {
        BirthInfo(
            date: mergedLocalBirthDateTime,
            latitude: birthLat,
            longitude: birthLng,
            timezoneOffsetMinutes: birthTimezoneOffsetMinutes,
            originalUserInput: birthRawTimeString
        )
    }

    // For Sun/Moon we want the absolute instant: local time minus offset = UTC
    private var birthDateUTC: Date {
        mergedLocalBirthDateTime.addingTimeInterval(-Double(birthTimezoneOffsetMinutes * 60))
    }

    // Display birth time exactly as typed (if available); otherwise format in birth timezone
    private var birthTimeDisplay: String {
        AstroCalculator.displayBirthTime(birthInfo, format: "yyyy-MM-dd HH:mm")
    }
    private var birthTimeDisplayOnly: String {
        AstroCalculator.displayBirthTime(birthInfo, format: "h:mm a").lowercased()
    }

    private var chartComputationSignature: String {
        let dateKey = Self.parseDateYYYYMMDD.string(from: birthday)
        let (hour, minute) = BirthTimeUtils.hourMinute(from: birthTime)
        let latKey = String(format: "%.6f", birthLat)
        let lngKey = String(format: "%.6f", birthLng)
        return "\(dateKey)|\(hour):\(minute)|\(latKey)|\(lngKey)|\(birthTimezoneOffsetMinutes)"
    }

    // Local fallback, used both for persistence and UI fallback while Firebase sync completes.
    private var fallbackSunSignText: String {
        AstroCalculator.sunSign(date: birthDateUTC).rawValue
    }
    private var fallbackMoonSignText: String {
        AstroCalculator.moonSign(date: birthDateUTC).rawValue
    }
    private var fallbackAscSignText: String {
        AstroCalculator.ascendantSign(info: birthInfo).rawValue
    }

    private var sunSignText: String {
        chartSunSign.isEmpty ? fallbackSunSignText : chartSunSign
    }
    private var moonSignText: String {
        chartMoonSign.isEmpty ? fallbackMoonSignText : chartMoonSign
    }
    private var ascSignText: String {
        chartAscSign.isEmpty ? fallbackAscSignText : chartAscSign
    }

}

// MARK: - 固定英文展示 & 解析（工具函数，供其它处复用）
private extension ProfileView {
    func dateString(_ d: Date) -> String {
        Self.birthdayDisplayFormatter.string(from: d)
    }
    func timeString(_ d: Date) -> String {
        Self.birthTimeDisplayFormatter.string(from: d).lowercased()
    }
    func timeToDate(_ s: String) -> Date? {
        if let d = Self.parseTimeFormatter12.date(from: s) { return d }
        if let d = Self.parseTimeFormatter24.date(from: s) { return d }
        return nil
    }
}


// 放在文件尾部的协调器（保持你的实现）
final class AppleReauthCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let nonce: String
    var presentingWindow: UIWindow?
    let completion: (Data?, Error?) -> Void

    init(nonce: String, completion: @escaping (Data?, Error?) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentingWindow ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken else {
            completion(nil, NSError(domain: "Aligna", code: -6, userInfo: [NSLocalizedDescriptionKey: "Apple credential missing token."]))
            return
        }
        completion(token, nil)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(nil, error)
    }
}

import Foundation
import CoreLocation



import Foundation
import CoreLocation

// 把出生“日期”和“时间”合并成一个本地民用时间 Date，再按出生地时区推导 UTC。
extension OnboardingViewModel {
    var birthDateTime: Date {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.current
        var dc = cal.dateComponents(in: tz, from: birth_date)
        let t  = cal.dateComponents(in: tz, from: birth_time)
        dc.hour = t.hour; dc.minute = t.minute; dc.second = t.second ?? 0
        return cal.date(from: DateComponents(timeZone: tz,
                                             year: dc.year, month: dc.month, day: dc.day,
                                             hour: dc.hour, minute: dc.minute, second: dc.second)) ?? birth_date
    }

    var birthDateUTC: Date {
        birthDateTime.addingTimeInterval(-Double(birthTimezoneOffsetMinutes * 60))
    }

    var sunSignText: String {
        AstroCalculator.sunSign(date: birthDateUTC).rawValue
    }

    var moonSignText: String {
        AstroCalculator.moonSign(date: birthDateUTC).rawValue
    }

    var ascendantText: String {
        guard let coord = birthCoordinate else { return "—" } // no coords → show dash
        let info = BirthInfo(
            date: birthDateTime,
            latitude: coord.latitude,
            longitude: coord.longitude,
            timezoneOffsetMinutes: birthTimezoneOffsetMinutes
        )
        return AstroCalculator.ascendantSign(info: info).rawValue
    }
}

import SwiftUI
