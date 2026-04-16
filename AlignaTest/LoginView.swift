import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import FirebaseCore
import UIKit

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showInfoAlert = false
    @State private var infoMessage = ""
    @State private var dismissAfterInfo = false
    @State private var showAuthOverlay = false
    @State private var currentNonce: String? = nil
    @State private var navigateToHome = false
    @State private var authBusy = false
    @State private var activeAuthAction: AuthAction? = nil
    @State private var showIntro = false
    @FocusState private var loginFocus: LoginField?
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?
    private enum LoginField { case email, password }
    private enum AuthAction { case emailLogin, google, apple, resetPassword }
    private var panelBG: Color { Color.white.opacity(0.10) }
    private func isActive(_ action: AuthAction) -> Bool {
        authBusy && activeAuthAction == action
    }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)
            let keyboardInset = max(0, keyboardHeight - geometry.safeAreaInsets.bottom)
            let isKeyboardVisible = keyboardInset > 0
            let headerTopPadding = isKeyboardVisible ? geometry.size.height * 0.015 : geometry.size.height * 0.05
            let sectionGap = isKeyboardVisible ? geometry.size.height * 0.01 : geometry.size.height * 0.03
            let headerGap = isKeyboardVisible ? geometry.size.height * 0.01 : geometry.size.height * 0.02
            let focusExtraSpace: CGFloat = isKeyboardVisible ? 32 : 0

            ZStack {
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .contentShape(Rectangle())
                    .onTapGesture { loginFocus = nil }

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
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
                        .disabled(authBusy)
                        .padding(.leading, geometry.size.width * 0.05)
                        .padding(.top, headerTopPadding)
                        Spacer()
                    }
                    .staggered(0, show: $showIntro)

                    Spacer(minLength: sectionGap)

                    // 标题区
                    VStack(spacing: minLength * 0.02) {
                        if let _ = UIImage(named: "alignaSymbol") {
                            Image("alignaSymbol")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: minLength * 0.14)
                                .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.92))
                                .staggered(0, show: $showIntro)
                        }

                        AlignaHeading(
                            textColor: themeManager.fixedNightTextPrimary,
                            show: $showIntro,
                            fontSize: minLength * 0.12,
                            letterSpacing: minLength * 0.005
                        )

                        VStack(spacing: 6) {
                            Text(String(localized: "login.welcome_back"))
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                    }
                    .staggered(1, show: $showIntro)

                    Spacer(minLength: headerGap)

                    // 表单
                    VStack(spacing: minLength * 0.035) {
                        // Google / Apple
                        VStack(spacing: minLength * 0.025) {
                            Button(action: {
                                guard !authBusy else { return }
                                activeAuthAction = .google
                                authBusy = true
                                showAuthOverlay = true
                                handleGoogleLogin(
                                    viewModel: viewModel,
                                    onSuccessToLogin: {
                                        authBusy = false
                                        activeAuthAction = nil
                                        showAuthOverlay = false
                                        UserDefaults.standard.set("google.com", forKey: "lastAuthProvider")
                                        if let user = Auth.auth().currentUser {
                                            viewModel.userId = user.uid
                                        }
                                        isLoggedIn = true
                                        UserDefaults.standard.set(true, forKey: "shouldShowBootLoading")
                                        UserDefaults.standard.set(true, forKey: "shouldShowBootLoading")
                                        UserDefaults.standard.set(true, forKey: "shouldShowBootLoading")
                                        UserDefaults.standard.set(true, forKey: "shouldShowBootLoading")
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        authBusy = false
                                        activeAuthAction = nil
                                        showAuthOverlay = false
                                        UserDefaults.standard.set("google.com", forKey: "lastAuthProvider")
                                        infoMessage = String(localized: "auth.account_incomplete_message")
                                        dismissAfterInfo = true
                                        showInfoAlert = true
                                    },
                                    onError: { message in
                                        authBusy = false
                                        activeAuthAction = nil
                                        showAuthOverlay = false
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }) {
                                HStack(spacing: 10) {
                                    if isActive(.google) {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(themeManager.fixedNightTextPrimary)
                                            .scaleEffect(0.75)
                                    }
                                    Image("googleIcon")
                                        .renderingMode(.template)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(.black)
                                        .frame(width: 24, height: 24)
                                    Text(String(localized: "login.sign_in_google"))
                                        .font(AlynnaTypography.font(.headline).weight(.semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(themeManager.fixedNightTextPrimary)
                                .cornerRadius(14)
                            }
                            .staggered(2, show: $showIntro)

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
                                        alertMessage = String(localized: "auth.missing_nonce")
                                        showAlert = true
                                        return
                                    }
                                    activeAuthAction = .apple
                                    authBusy = true
                                    showAuthOverlay = true
                                    handleAppleLogin(
                                        result: result,
                                        rawNonce: raw,
                                        onSuccessToLogin: {
                                            authBusy = false
                                            activeAuthAction = nil
                                            showAuthOverlay = false
                                            UserDefaults.standard.set("apple.com", forKey: "lastAuthProvider")
                                            if let user = Auth.auth().currentUser {
                                                viewModel.userId = user.uid
                                            }
                                            isLoggedIn = true
                                            navigateToHome = true
                                        },
                                        onSuccessToOnboarding: {
                                            authBusy = false
                                            activeAuthAction = nil
                                            showAuthOverlay = false
                                            UserDefaults.standard.set("apple.com", forKey: "lastAuthProvider")
                                            if let user = Auth.auth().currentUser {
                                                viewModel.userId = user.uid
                                            }
                                            infoMessage = String(localized: "auth.account_incomplete_message")
                                            dismissAfterInfo = true
                                            showInfoAlert = true
                                        },
                                        onError: { message in
                                            authBusy = false
                                            activeAuthAction = nil
                                            showAuthOverlay = false
                                            alertMessage = message
                                            showAlert = true
                                        }
                                    )
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .frame(height: 50)
                            .staggered(3, show: $showIntro)
                        }
                        .padding(.top, 2)

                        // 分隔线
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                            Text(String(localized: "auth.or_with"))
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                        }
                        .staggered(4, show: $showIntro)

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
                                    Text(String(localized: "auth.email_placeholder"))
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
                                .id(LoginField.email)
                        }
                        .staggered(5, show: $showIntro)
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
                                    Text(String(localized: "auth.password_placeholder"))
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
                                .onSubmit { loginFocus = nil }
                                .id(LoginField.password)
                        }
                        .staggered(6, show: $showIntro)
                        .animation(nil, value: loginFocus)

                        // Forgot Password
                        HStack {
                            Spacer()
                            Button(String(localized: "login.forgot_password")) {
                                guard !authBusy else { return }
                                if email.isEmpty {
                                    alertMessage = String(localized: "login.enter_email_first")
                                    showAuthOverlay = false
                                    showAlert = true
                                    return
                                }
                                activeAuthAction = .resetPassword
                                authBusy = true
                                Auth.auth().sendPasswordReset(withEmail: email) { error in
                                    authBusy = false
                                    activeAuthAction = nil
                                    if let error = error {
                                        alertMessage = error.localizedDescription
                                    } else {
                                        alertMessage = String(localized: "login.reset_email_sent")
                                    }
                                    showAlert = true
                                }
                            }
                            .font(AlynnaTypography.font(.footnote))
                            .foregroundColor(themeManager.fixedNightTextSecondary)
                            .underline()
                        }
                        .staggered(7, show: $showIntro)

                        // Log In
                        Button(action: {
                            guard !authBusy else { return }
                            if email.isEmpty || password.isEmpty {
                                alertMessage = String(localized: "login.email_password_required")
                                showAlert = true
                                return
                            }
                            activeAuthAction = .emailLogin
                            authBusy = true
                            showAuthOverlay = true
                            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                                authBusy = false
                                activeAuthAction = nil
                                if let user = Auth.auth().currentUser {
                                    viewModel.userId = user.uid
                                }
                                if let error = error {
                                    if let code = AuthErrorCode(rawValue: (error as NSError).code) {
                                        switch code {
                                        case .wrongPassword: alertMessage = String(localized: "login.error_wrong_password")
                                        case .invalidEmail: alertMessage = String(localized: "login.error_invalid_email")
                                        case .userDisabled: alertMessage = String(localized: "login.error_user_disabled")
                                        case .userNotFound: alertMessage = String(localized: "login.error_user_not_found")
                                        default: alertMessage = error.localizedDescription
                                        }
                                    } else {
                                        alertMessage = error.localizedDescription
                                    }
                                    showAuthOverlay = false
                                    showAlert = true
                                    return
                                }

                                if let user = Auth.auth().currentUser, !user.isEmailVerified {
                                    user.sendEmailVerification(completion: nil)
                                    try? Auth.auth().signOut()
                                    showAuthOverlay = false
                                    alertMessage = String(localized: "login.error_verify_email")
                                    showAlert = true
                                    return
                                }

                                UserDefaults.standard.set("password", forKey: "lastAuthProvider")
                                routeAuthenticatedUser(
                                    onSuccessToLogin: {
                                        authBusy = false
                                        activeAuthAction = nil
                                        showAuthOverlay = false
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        authBusy = false
                                        activeAuthAction = nil
                                        showAuthOverlay = false
                                        if let user = Auth.auth().currentUser {
                                            viewModel.userId = user.uid
                                        }
                                        infoMessage = String(localized: "auth.account_incomplete_message")
                                        dismissAfterInfo = true
                                        showInfoAlert = true
                                    },
                                    onError: { message in
                                        authBusy = false
                                        activeAuthAction = nil
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isActive(.emailLogin) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.black)
                                        .scaleEffect(0.75)
                                }
                                Text(isActive(.emailLogin) ? String(localized: "login.signing_in") : String(localized: "login.log_in"))
                            }
                            .font(AlynnaTypography.font(.headline).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.fixedNightTextPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(14)
                        }
                        .disabled(authBusy)
                        .staggered(8, show: $showIntro)

                        // 去注册
                        HStack {
                            Text(String(localized: "login.no_account"))
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            NavigationLink(
                                destination: SignUpView()
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                                    .environmentObject(viewModel)
                            ) {
                                Text(String(localized: "login.create_account"))
                                    .font(AlynnaTypography.font(.footnote).weight(.semibold))
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .underline()
                            }
                        }
                        .padding(.top)
                        .staggered(9, show: $showIntro)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    Spacer(minLength: geometry.size.height * 0.08)
                    Color.clear
                        .frame(height: focusExtraSpace)
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardInset)
                    .allowsHitTesting(false)
            }
            .onChange(of: loginFocus) { _, newValue in
                guard let target = newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
            .onChange(of: keyboardHeight) { _, _ in
                guard let target = loginFocus else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
        }
    }
    .fullScreenCover(isPresented: $navigateToHome) {
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
                loginFocus = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                registerKeyboardNotifications()
            }
            .onDisappear {
                showIntro = false
                unregisterKeyboardNotifications()
            }
            .overlay {
                if showAuthOverlay {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(themeManager.fixedNightTextPrimary)
                                .scaleEffect(1.05)
                            Text(String(localized: "login.logging_in_overlay"))
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(14)
                    }
                }
            }
            .overlay {
                if showAlert {
                    AlynnaActionDialog(
                        title: String(localized: "auth.dialog_error_title"),
                        message: alertMessage,
                        symbol: "exclamationmark.circle",
                        tone: .error,
                        dismissButtonTitle: String(localized: "auth.dialog_ok"),
                        onDismiss: { showAlert = false }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
                } else if showInfoAlert {
                    AlynnaActionDialog(
                        title: String(localized: "login.almost_there_title"),
                        message: infoMessage,
                        symbol: "person.crop.circle.badge.exclamationmark",
                        tone: .info,
                        dismissButtonTitle: String(localized: "auth.dialog_continue"),
                        onDismiss: {
                            showInfoAlert = false
                    if dismissAfterInfo {
                        dismissAfterInfo = false
                        dismiss()
                    }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func registerKeyboardNotifications() {
        guard keyboardShowObserver == nil, keyboardHideObserver == nil else { return }

        keyboardShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = frame.height
            }
        }

        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = 0
            }
        }
    }

    private func unregisterKeyboardNotifications() {
        if let observer = keyboardShowObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardShowObserver = nil
        }
        if let observer = keyboardHideObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardHideObserver = nil
        }
    }
}
#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(StarAnimationManager())
            .environmentObject(ThemeManager())
            .environmentObject(OnboardingViewModel())
    }
}
