import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import FirebaseFirestore
import UIKit

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showInfoAlert = false
    @State private var infoMessage = ""
    @State private var showVerifyAlert = false
    @State private var verifyMessage = "We sent a verification email. Please verify and then continue."
    @State private var isVerifyingEmail = false
    @State private var navigateToOnboarding = false
    @State private var navigateToLogin = false
    @State private var navigateToLoginOnDismiss = false
    @State private var currentNonce: String? = nil
    @State private var authBusy = false
    @State private var activeAuthAction: AuthAction? = nil

    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @StateObject private var appleAuth = AppleAuthManager()
    @State private var showIntro = false
    @FocusState private var registerFocus: RegisterField?
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?

    private enum RegisterField { case email, password }
    private enum AuthAction { case emailSignUp, google, apple }
    private func isActive(_ action: AuthAction) -> Bool {
        authBusy && activeAuthAction == action
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minL = min(w, h)

                let keyboardInset = max(0, keyboardHeight - geometry.safeAreaInsets.bottom)
                let isKeyboardVisible = keyboardInset > 0
                let sectionGap = isKeyboardVisible ? h * 0.02 : h * 0.075
                let fieldGap = minL * 0.030
                let headerTopPadding = isKeyboardVisible ? h * 0.015 : h * 0.05
                let focusExtraSpace: CGFloat = isKeyboardVisible ? 32 : 0

                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .contentShape(Rectangle())
                        .onTapGesture { registerFocus = nil }

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                VStack(spacing: minL * 0.02) {
                                    HStack {
                                        Button(action: { dismiss() }) {
                                            Image(systemName: "chevron.left")
                                                .font(AlynnaTypography.font(.title2))
                                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                                .padding(10)
                                                .background(Color.white.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .disabled(authBusy)
                                        .padding(.leading, w * 0.05)
                                        Spacer()
                                    }

                                    VStack(spacing: 8) {
                                        if let _ = UIImage(named: "alignaSymbol") {
                                            Image("alignaSymbol")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: minL * 0.14)
                                                .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.92))
                                                .staggered(0, show: $showIntro)
                                        }

                                        AlignaHeading(
                                            textColor: themeManager.fixedNightTextPrimary,
                                            show: $showIntro,
                                            fontSize: minL * 0.12,
                                            letterSpacing: minL * 0.005
                                        )
                                        Text("Create Your Space")
                                            .font(AlynnaTypography.font(.subheadline))
                                            .foregroundColor(themeManager.fixedNightTextSecondary)
                                    }
                                    .padding(.top, h * 0.01)
                                    .staggered(1, show: $showIntro)
                                }
                                .padding(.top, headerTopPadding)
                                .staggered(0, show: $showIntro)

                                Spacer(minLength: sectionGap)

                                VStack(spacing: fieldGap) {
                                    VStack(spacing: minL * 0.025) {
                                        Button(action: {
                                            guard !authBusy else { return }
                                            activeAuthAction = .google
                                            authBusy = true
                                            hasCompletedOnboarding = false
                                            isLoggedIn = false
                                            shouldOnboardAfterSignIn = true

                                            if !GoogleSignInDiagnostics.preflight(context: "SignUpView.GoogleButton") {
                                                authBusy = false
                                                activeAuthAction = nil
                                                alertMessage = ""
                                                showAlert = true
                                                return
                                            }

                                            handleGoogleFromRegister(
                                                onNewUserGoOnboarding: {
                                                    authBusy = false
                                                    activeAuthAction = nil
                                                    if let user = Auth.auth().currentUser {
                                                        viewModel.userId = user.uid
                                                    }
                                                    shouldOnboardAfterSignIn = true
                                                    navigateToOnboarding = true
                                                },
                                                onExistingUserGoLogin: { msg in
                                                    authBusy = false
                                                    activeAuthAction = nil
                                                    shouldOnboardAfterSignIn = false
                                                    infoMessage = msg
                                                    navigateToLoginOnDismiss = true
                                                    showInfoAlert = true
                                                },
                                                onError: { message in
                                                    authBusy = false
                                                    activeAuthAction = nil
                                                    shouldOnboardAfterSignIn = false
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
                                                Text("Sign up with Google")
                                                    .font(AlynnaTypography.font(.headline))
                                            }
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(themeManager.fixedNightTextPrimary)
                                            .cornerRadius(14)
                                        }
                                        .disabled(authBusy)
                                        .staggered(2, show: $showIntro)

                                        ZStack {
                                            HStack(spacing: 10) {
                                                if isActive(.apple) {
                                                    ProgressView()
                                                        .progressViewStyle(.circular)
                                                        .tint(.black)
                                                        .scaleEffect(0.75)
                                                }
                                                Image(systemName: "applelogo")
                                                    .font(.system(size: 16, weight: .regular))
                                                    .frame(width: 24, height: 24)
                                                Text("Sign up with Apple")
                                                    .font(AlynnaTypography.font(.headline))
                                            }
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(themeManager.fixedNightTextPrimary)
                                            .cornerRadius(14)

                                            SignInWithAppleButton(
                                                .signUp,
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
                                                    activeAuthAction = .apple
                                                    authBusy = true
                                                    hasCompletedOnboarding = false
                                                    isLoggedIn = false
                                                    shouldOnboardAfterSignIn = true

                                                    handleAppleFromRegister(
                                                        result: result,
                                                        rawNonce: raw,
                                                        onNewUserGoOnboarding: {
                                                            DispatchQueue.main.async {
                                                                authBusy = false
                                                                activeAuthAction = nil
                                                                if let user = Auth.auth().currentUser {
                                                                    viewModel.userId = user.uid
                                                                }
                                                                shouldOnboardAfterSignIn = true
                                                                navigateToOnboarding = true
                                                            }
                                                        },
                                                        onExistingUserGoLogin: { msg in
                                                            DispatchQueue.main.async {
                                                                authBusy = false
                                                                activeAuthAction = nil
                                                                shouldOnboardAfterSignIn = false
                                                                infoMessage = msg
                                                                navigateToLoginOnDismiss = true
                                                                showInfoAlert = true
                                                            }
                                                        },
                                                        onError: { message in
                                                            DispatchQueue.main.async {
                                                                authBusy = false
                                                                activeAuthAction = nil
                                                                shouldOnboardAfterSignIn = false
                                                                alertMessage = message
                                                                showAlert = true
                                                            }
                                                        }
                                                    )
                                                }
                                            )
                                            .signInWithAppleButtonStyle(.white)
                                            .frame(height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .opacity(0.02)
                                        }
                                        .frame(height: 50)
                                        .disabled(authBusy)
                                        .staggered(3, show: $showIntro)
                                    }
                                    .padding(.top, 2)

                                    HStack {
                                        Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                                        Text("Or with")
                                            .font(AlynnaTypography.font(.footnote))
                                            .foregroundColor(themeManager.fixedNightTextSecondary)
                                        Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                                    }
                                    .staggered(4, show: $showIntro)

                                    Group {
                                        TextField("", text: $email)
                                            .textContentType(.emailAddress)
                                            .keyboardType(.emailAddress)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .padding(.vertical, 14)
                                            .padding(.leading, 16)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.fixedNightTextPrimary)
                                            .placeholder(when: email.isEmpty) {
                                                Text("Enter your email")
                                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                                    .padding(.leading, 16)
                                            }
                                            .focused($registerFocus, equals: .email)
                                            .focusGlow(
                                                active: registerFocus == .email,
                                                color: themeManager.fixedNightTextPrimary,
                                                lineWidth: 2.2,
                                                cornerRadius: 14
                                            )
                                            .submitLabel(.next)
                                            .onSubmit { registerFocus = .password }
                                            .id(RegisterField.email)
                                    }
                                    .staggered(5, show: $showIntro)
                                    .animation(nil, value: registerFocus)

                                    Group {
                                        SecureField("", text: $password)
                                            .padding(.vertical, 14)
                                            .padding(.leading, 16)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.fixedNightTextPrimary)
                                            .placeholder(when: password.isEmpty) {
                                                Text("Enter your password")
                                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                                    .padding(.leading, 16)
                                            }
                                            .focused($registerFocus, equals: .password)
                                            .focusGlow(
                                                active: registerFocus == .password,
                                                color: themeManager.fixedNightTextPrimary,
                                                lineWidth: 2.2,
                                                cornerRadius: 14
                                            )
                                            .submitLabel(.done)
                                            .onSubmit { registerFocus = nil }
                                            .id(RegisterField.password)
                                    }
                                    .staggered(6, show: $showIntro)
                                    .animation(nil, value: registerFocus)

                                    Button(action: {
                                        guard !authBusy else { return }
                                        activeAuthAction = .emailSignUp
                                        registerWithEmailPassword()
                                    }) {
                                        HStack(spacing: 8) {
                                            if isActive(.emailSignUp) {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.black)
                                                    .scaleEffect(0.75)
                                            }
                                            Text(isActive(.emailSignUp) ? "Creating..." : "Create Account")
                                        }
                                        .font(AlynnaTypography.font(.headline))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(themeManager.fixedNightTextPrimary)
                                        .foregroundColor(.black)
                                        .cornerRadius(14)
                                    }
                                    .disabled(authBusy)
                                    .staggered(7, show: $showIntro)
                                }
                                .padding(.horizontal, w * 0.1)

                                Spacer(minLength: h * 0.08)
                                Color.clear
                                    .frame(height: focusExtraSpace)
                            }
                            .frame(minHeight: h)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear
                                .frame(height: keyboardInset)
                                .allowsHitTesting(false)
                        }
                        .onChange(of: registerFocus) { _, newValue in
                            guard let target = newValue else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(target, anchor: .bottom)
                            }
                        }
                        .onChange(of: keyboardHeight) { _, _ in
                            guard let target = registerFocus else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(target, anchor: .bottom)
                            }
                        }
                    }
                    .preferredColorScheme(.dark)
                    .transaction { $0.animation = nil }

                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Notice"),
                          message: Text(alertMessage),
                          dismissButton: .default(Text("OK")))
                }
                .alert("Sign In", isPresented: $showInfoAlert) {
                    Button("Continue") {
                        if navigateToLoginOnDismiss {
                            navigateToLoginOnDismiss = false
                            navigateToLogin = true
                        }
                    }
                } message: {
                    Text(infoMessage)
                }
                .alert("Verify Email", isPresented: $showVerifyAlert) {
                    Button("I Verified") {
                        guard !isVerifyingEmail else { return }
                        isVerifyingEmail = true
                        checkEmailVerificationAndContinue()
                    }
                    .disabled(isVerifyingEmail)
                    Button("Resend") {
                        guard !isVerifyingEmail else { return }
                        resendVerificationEmail()
                    }
                    .disabled(isVerifyingEmail)
                    Button("Cancel", role: .cancel) { }
                        .disabled(isVerifyingEmail)
                } message: {
                    Text(verifyMessage)
                }
                .navigationDestination(isPresented: $navigateToOnboarding) {
                    OnboardingStep1(viewModel: viewModel)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                }
                .navigationDestination(isPresented: $navigateToLogin) {
                    LoginView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .environmentObject(viewModel)
                }
                .overlay {
                    if isVerifyingEmail {
                        ZStack {
                            Color.black.opacity(0.35)
                                .ignoresSafeArea()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Checking verification…")
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
                .onAppear {
                    showIntro = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                    _ = GoogleSignInDiagnostics.run(context: "SignUpView.onAppear")
                    registerKeyboardNotifications()
                }
                .onDisappear {
                    showIntro = false
                    unregisterKeyboardNotifications()
                }
                .navigationBarBackButtonHidden(true)
            }
        }
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

    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }

        authBusy = true
        hasCompletedOnboarding = false
        isLoggedIn = false
        shouldOnboardAfterSignIn = true

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                authBusy = false
                activeAuthAction = nil
                if let errCode = AuthErrorCode(rawValue: error._code),
                   errCode == .emailAlreadyInUse {
                    // Attempt direct login with the provided credentials.
                    Auth.auth().signIn(withEmail: email, password: password) { result, signInError in
                        DispatchQueue.main.async {
                            if let signInError = signInError {
                                authBusy = false
                                activeAuthAction = nil
                                alertMessage = signInError.localizedDescription
                                showAlert = true
                                return
                            }

                            guard let user = result?.user else {
                                authBusy = false
                                activeAuthAction = nil
                                alertMessage = "Sign in failed. Please try again."
                                showAlert = true
                                return
                            }
                            viewModel.userId = user.uid

                            if !user.isEmailVerified {
                                user.sendEmailVerification(completion: nil)
                                try? Auth.auth().signOut()
                                authBusy = false
                                activeAuthAction = nil
                                verifyMessage = "We sent a verification email to \(email). Please verify, then tap 'I Verified' to continue."
                                showVerifyAlert = true
                                return
                            }

                            routeAuthenticatedUser(
                                onSuccessToLogin: {
                                    authBusy = false
                                    activeAuthAction = nil
                                    isLoggedIn = true
                                    dismiss()
                                },
                                onSuccessToOnboarding: {
                                    authBusy = false
                                    activeAuthAction = nil
                                    navigateToOnboarding = true
                                },
                                onError: { message in
                                    authBusy = false
                                    activeAuthAction = nil
                                    alertMessage = message
                                    showAlert = true
                                }
                            )
                        }
                    }
                    return
                }

                alertMessage = error.localizedDescription
                showAlert = true
                return
            }

            if let user = result?.user {
                viewModel.userId = user.uid
            }
            result?.user.sendEmailVerification(completion: nil)
            // Enforce verification: sign out until verified.
            try? Auth.auth().signOut()
            DispatchQueue.main.async {
                authBusy = false
                activeAuthAction = nil
                verifyMessage = "We sent a verification email to \(email). Please verify, then tap 'I Verified' to continue."
                showVerifyAlert = true
            }
        }
    }

    private func resendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification(completion: nil)
    }

    private func checkEmailVerificationAndContinue() {
        func proceed(with user: User) {
            authBusy = true
            user.reload { error in
                DispatchQueue.main.async {
                    authBusy = false
                    isVerifyingEmail = false
                    if let error = error {
                        alertMessage = error.localizedDescription
                        showAlert = true
                        return
                    }

                    if user.isEmailVerified {
                        showVerifyAlert = false
                        viewModel.userId = user.uid
                        routeAuthenticatedUser(
                            onSuccessToLogin: {
                                isLoggedIn = true
                                dismiss()
                            },
                            onSuccessToOnboarding: {
                                isLoggedIn = true
                                navigateToOnboarding = true
                            },
                            onError: { message in
                                alertMessage = message
                                showAlert = true
                            }
                        )
                    } else {
                        alertMessage = "Email not verified yet. Please check your inbox, then try again."
                        showAlert = true
                    }
                }
            }
        }

        // Case 1: Session exists, just reload
        if let user = Auth.auth().currentUser {
            proceed(with: user)
            return
        }

        // Case 2: Session missing, try silent sign-in with the email/password on this screen
        if !email.isEmpty, !password.isEmpty {
            authBusy = true
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    if let user = result?.user {
                        proceed(with: user)
                    } else {
                        authBusy = false
                        isVerifyingEmail = false
                        infoMessage = "会话已过期，请登录后继续。"
                        navigateToLoginOnDismiss = true
                        showInfoAlert = true
                    }
                }
            }
            return
        }

        // Case 3: No session and no credentials available (e.g., app restarted). Ask user to login.
        isVerifyingEmail = false
        infoMessage = "会话已过期，请登录后继续。"
        navigateToLoginOnDismiss = true
        showInfoAlert = true
    }
}

#Preview("Sign Up") {
    NavigationStack {
        SignUpView()
            .environmentObject(StarAnimationManager())
            .environmentObject(ThemeManager())
            .environmentObject(OnboardingViewModel())
    }
}
