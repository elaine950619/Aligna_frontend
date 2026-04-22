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
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showInfoAlert = false
    @State private var infoMessage = ""
    @State private var navigateToOnboarding = false
    @State private var showAuthOverlay = false
    @State private var navigateToLogin = false
    @State private var navigateToLoginOnDismiss = false
    @State private var prefillLoginEmail: String = ""
    @State private var showEmailInUseDialog = false
    @State private var showResetSentDialog = false
    @State private var resetSentMessage: String = ""
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

    private enum RegisterField { case email, password, confirmPassword }
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
                    AppBackgroundView(nightMotion: .animated)
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
                                                .foregroundColor(themeManager.primaryText)
                                                .padding(10)
                                                .background(themeManager.panelFill.opacity(0.25))
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
                                                .foregroundColor(themeManager.primaryText.opacity(0.92))
                                                .staggered(0, show: $showIntro)
                                        }

                                        AlignaHeading(
                                            textColor: themeManager.primaryText,
                                            show: $showIntro,
                                            fontSize: minL * 0.12,
                                            letterSpacing: minL * 0.005
                                        )
                                        Text(String(localized: "signup.create_your_space"))
                                            .font(AlynnaTypography.font(.subheadline))
                                            .foregroundColor(themeManager.descriptionText)
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
                                            showAuthOverlay = true
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
                                                    showAuthOverlay = false
                                                    UserDefaults.standard.set("google.com", forKey: "lastAuthProvider")
                                                    if let user = Auth.auth().currentUser {
                                                        viewModel.userId = user.uid
                                                    }
                                                    shouldOnboardAfterSignIn = true
                                                    proceedToOnboarding()
                                                },
                                                onExistingUserGoLogin: { msg in
                                                    authBusy = false
                                                    activeAuthAction = nil
                                                    showAuthOverlay = false
                                                    UserDefaults.standard.set("google.com", forKey: "lastAuthProvider")
                                                    shouldOnboardAfterSignIn = false
                                                    infoMessage = msg
                                                    navigateToLoginOnDismiss = true
                                                    showInfoAlert = true
                                                },
                                                onError: { message in
                                                    authBusy = false
                                                    activeAuthAction = nil
                                                    showAuthOverlay = false
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
                                                        .tint(themeManager.buttonForegroundOnPrimary)
                                                        .scaleEffect(0.75)
                                                }
                                                Image("googleIcon")
                                                    .renderingMode(.template)
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(themeManager.buttonForegroundOnPrimary)
                                                    .frame(width: 24, height: 24)
                                                Text(String(localized: "signup.sign_up_google"))
                                                    .font(AlynnaTypography.font(.headline).weight(.semibold))
                                            }
                                            .foregroundColor(themeManager.buttonForegroundOnPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(themeManager.accent)
                                            .cornerRadius(14)
                                        }
                                        .disabled(authBusy)
                                        .staggered(2, show: $showIntro)

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
                                                    alertMessage = String(localized: "auth.missing_nonce")
                                                    showAlert = true
                                                    return
                                                }
                                                activeAuthAction = .apple
                                                authBusy = true
                                                showAuthOverlay = true
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
                                                            showAuthOverlay = false
                                                            UserDefaults.standard.set("apple.com", forKey: "lastAuthProvider")
                                                            if let user = Auth.auth().currentUser {
                                                                viewModel.userId = user.uid
                                                            }
                                                            shouldOnboardAfterSignIn = true
                                                            proceedToOnboarding()
                                                        }
                                                    },
                                                    onExistingUserGoLogin: { msg in
                                                        DispatchQueue.main.async {
                                                            authBusy = false
                                                            activeAuthAction = nil
                                                            showAuthOverlay = false
                                                            UserDefaults.standard.set("apple.com", forKey: "lastAuthProvider")
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
                                                            showAuthOverlay = false
                                                            shouldOnboardAfterSignIn = false
                                                            alertMessage = message
                                                            showAlert = true
                                                        }
                                                    }
                                                )
                                            }
                                        )
                                        .signInWithAppleButtonStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .disabled(authBusy)
                                        .staggered(3, show: $showIntro)
                                    }
                                    .padding(.top, 2)

                                    HStack {
                                        Rectangle().fill(themeManager.descriptionText.opacity(0.20)).frame(height: 1)
                                        Text(String(localized: "auth.or_with"))
                                            .font(AlynnaTypography.font(.footnote))
                                            .foregroundColor(themeManager.descriptionText)
                                        Rectangle().fill(themeManager.descriptionText.opacity(0.20)).frame(height: 1)
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
                                            .background(themeManager.panelFill.opacity(0.25))
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.primaryText)
                                            .placeholder(when: email.isEmpty) {
                                                Text(String(localized: "auth.email_placeholder"))
                                                    .foregroundColor(themeManager.descriptionText)
                                                    .padding(.leading, 16)
                                            }
                                            .focused($registerFocus, equals: .email)
                                            .focusGlow(
                                                active: registerFocus == .email,
                                                color: themeManager.primaryText,
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
                                            .textContentType(.newPassword)
                                            .padding(.vertical, 14)
                                            .padding(.leading, 16)
                                            .background(themeManager.panelFill.opacity(0.25))
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.primaryText)
                                            .placeholder(when: password.isEmpty) {
                                                Text(String(localized: "auth.password_placeholder"))
                                                    .foregroundColor(themeManager.descriptionText)
                                                    .padding(.leading, 16)
                                            }
                                            .focused($registerFocus, equals: .password)
                                            .focusGlow(
                                                active: registerFocus == .password,
                                                color: themeManager.primaryText,
                                                lineWidth: 2.2,
                                                cornerRadius: 14
                                            )
                                            .submitLabel(.next)
                                            .onSubmit { registerFocus = .confirmPassword }
                                            .id(RegisterField.password)
                                    }
                                    .staggered(6, show: $showIntro)
                                    .animation(nil, value: registerFocus)

                                    Group {
                                        SecureField("", text: $confirmPassword)
                                            .textContentType(.newPassword)
                                            .padding(.vertical, 14)
                                            .padding(.leading, 16)
                                            .background(themeManager.panelFill.opacity(0.25))
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.primaryText)
                                            .placeholder(when: confirmPassword.isEmpty) {
                                                Text(String(localized: "auth.confirm_password_placeholder"))
                                                    .foregroundColor(themeManager.descriptionText)
                                                    .padding(.leading, 16)
                                            }
                                            .focused($registerFocus, equals: .confirmPassword)
                                            .focusGlow(
                                                active: registerFocus == .confirmPassword,
                                                color: themeManager.primaryText,
                                                lineWidth: 2.2,
                                                cornerRadius: 14
                                            )
                                            .submitLabel(.done)
                                            .onSubmit { registerFocus = nil }
                                            .id(RegisterField.confirmPassword)
                                    }
                                    .staggered(6, show: $showIntro)
                                    .animation(nil, value: registerFocus)

                                    Text(String(localized: "auth.password_requirements_hint"))
                                        .font(AlynnaTypography.font(.footnote))
                                        .foregroundColor(themeManager.descriptionText.opacity(0.70))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                        .staggered(6, show: $showIntro)

                                    Button(action: {
                                        guard !authBusy else { return }
                                        activeAuthAction = .emailSignUp
                                        showAuthOverlay = true
                                        registerWithEmailPassword()
                                    }) {
                                        HStack(spacing: 8) {
                                            if isActive(.emailSignUp) {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(themeManager.buttonForegroundOnPrimary)
                                                    .scaleEffect(0.75)
                                            }
                                            Text(isActive(.emailSignUp) ? String(localized: "signup.creating") : String(localized: "signup.create_account"))
                                        }
                                        .font(AlynnaTypography.font(.headline).weight(.semibold))
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(themeManager.accent)
                                        .foregroundColor(themeManager.buttonForegroundOnPrimary)
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
                    .preferredColorScheme(themeManager.preferredColorScheme)
                    .transaction { $0.animation = nil }

                }
                .overlay {
                    if showAlert {
                        AlynnaActionDialog(
                            title: String(localized: "signup.dialog_notice_title"),
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
                            title: String(localized: "signup.dialog_signin_title"),
                            message: infoMessage,
                            symbol: "arrow.right.circle",
                            tone: .info,
                            dismissButtonTitle: String(localized: "auth.dialog_continue"),
                            onDismiss: {
                                showInfoAlert = false
                        if navigateToLoginOnDismiss {
                            navigateToLoginOnDismiss = false
                            navigateToLogin = true
                        }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(20)
                    } else if showEmailInUseDialog {
                        AlynnaActionDialog(
                            title: String(localized: "signup.dialog_email_in_use_title"),
                            message: String(format: String(localized: "signup.dialog_email_in_use_message"), prefillLoginEmail),
                            symbol: "person.crop.circle.badge.exclamationmark",
                            tone: .info,
                            primaryButtonTitle: String(localized: "signup.dialog_go_to_login"),
                            primaryAction: {
                                showEmailInUseDialog = false
                                navigateToLogin = true
                            },
                            secondaryButtonTitle: String(localized: "auth.forgot_password"),
                            secondaryAction: {
                                showEmailInUseDialog = false
                                sendPasswordResetFromSignUp()
                            },
                            dismissButtonTitle: String(localized: "signup.dialog_cancel"),
                            onDismiss: { showEmailInUseDialog = false }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(20)
                    } else if showResetSentDialog {
                        AlynnaActionDialog(
                            title: String(localized: "auth.password_reset_sent_title"),
                            message: resetSentMessage,
                            symbol: "envelope.arrow.triangle.branch",
                            tone: .info,
                            dismissButtonTitle: String(localized: "auth.dialog_ok"),
                            onDismiss: { showResetSentDialog = false }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(20)
                    }
                }
                .navigationDestination(isPresented: $navigateToOnboarding) {
                    OnboardingStep0(viewModel: viewModel)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                }
                .navigationDestination(isPresented: $navigateToLogin) {
                    LoginView(initialEmail: prefillLoginEmail)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .environmentObject(viewModel)
                }
                .overlay {
                    if showAuthOverlay {
                        ZStack {
                            Color.black.opacity(0.35)
                                .ignoresSafeArea()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(themeManager.primaryText)
                                    .scaleEffect(1.05)
                                Text(String(localized: "signup.overlay_signing_up"))
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.primaryText)
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

    private func proceedToOnboarding() {
        guard Auth.auth().currentUser != nil else {
            authBusy = false
            activeAuthAction = nil
            showAuthOverlay = false
            shouldOnboardAfterSignIn = false
            alertMessage = String(localized: "signup.error_session_expired")
            showAlert = true
            return
        }
        isLoggedIn = true
        navigateToOnboarding = true
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
        // Client-side validation before hitting Firebase — avoids round-trips
        // and lets us show localized, specific errors instead of Firebase's
        // raw English messages.
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            showAuthOverlay = false
            authBusy = false
            activeAuthAction = nil
            alertMessage = String(localized: "signup.error_fill_fields")
            showAlert = true
            return
        }

        guard isValidEmailFormat(trimmedEmail) else {
            showAuthOverlay = false
            authBusy = false
            activeAuthAction = nil
            alertMessage = String(localized: "auth.error_invalid_email")
            showAlert = true
            return
        }

        guard password.count >= 6 else {
            showAuthOverlay = false
            authBusy = false
            activeAuthAction = nil
            alertMessage = String(localized: "auth.error_weak_password")
            showAlert = true
            return
        }

        guard password == confirmPassword else {
            showAuthOverlay = false
            authBusy = false
            activeAuthAction = nil
            alertMessage = String(localized: "auth.error_password_mismatch")
            showAlert = true
            return
        }

        authBusy = true
        hasCompletedOnboarding = false
        isLoggedIn = false
        shouldOnboardAfterSignIn = true

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    authBusy = false
                    activeAuthAction = nil
                    showAuthOverlay = false

                    if let errCode = AuthErrorCode(rawValue: error._code) {
                        switch errCode {
                        case .emailAlreadyInUse:
                            // Explicit path: show a dialog offering Login or
                            // Reset Password rather than silently attempting
                            // sign-in with the provided credentials.
                            prefillLoginEmail = trimmedEmail
                            showEmailInUseDialog = true
                            return
                        case .invalidEmail:
                            alertMessage = String(localized: "auth.error_invalid_email")
                        case .weakPassword:
                            alertMessage = String(localized: "auth.error_weak_password")
                        case .networkError:
                            alertMessage = String(localized: "auth.error_network")
                        case .tooManyRequests:
                            alertMessage = String(localized: "auth.error_too_many_requests")
                        default:
                            alertMessage = error.localizedDescription
                        }
                        showAlert = true
                        return
                    }

                    alertMessage = error.localizedDescription
                    showAlert = true
                }
                return
            }

            if let user = result?.user {
                viewModel.userId = user.uid
            }
            // Fire-and-forget the verification email. We don't gate on it —
                // the user can proceed straight into onboarding, and a
                // non-blocking banner on MainView will remind them to verify.
            result?.user.sendEmailVerification(completion: nil)
            UserDefaults.standard.set("password", forKey: "lastAuthProvider")
            DispatchQueue.main.async {
                routeAuthenticatedUser(
                    onSuccessToLogin: {
                        authBusy = false
                        activeAuthAction = nil
                        showAuthOverlay = false
                        isLoggedIn = true
                        dismiss()
                    },
                    onSuccessToOnboarding: {
                        authBusy = false
                        activeAuthAction = nil
                        showAuthOverlay = false
                        proceedToOnboarding()
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
        }
    }

    private func isValidEmailFormat(_ s: String) -> Bool {
        // Lightweight format check — good enough to reject obvious typos
        // before Firebase round-trip; Firebase does the authoritative check.
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    /// Send a password reset for the email already entered in the signup form.
    /// Triggered from the "email already in use" dialog.
    private func sendPasswordResetFromSignUp() {
        let target = prefillLoginEmail.isEmpty
            ? email.trimmingCharacters(in: .whitespacesAndNewlines)
            : prefillLoginEmail
        guard !target.isEmpty else { return }
        Auth.auth().sendPasswordReset(withEmail: target) { error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    return
                }
                resetSentMessage = String(format: String(localized: "auth.password_reset_sent"), target)
                showResetSentDialog = true
            }
        }
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
