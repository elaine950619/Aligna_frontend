import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import FirebaseFirestore

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
    @State private var navigateToOnboarding = false
    @State private var navigateToLogin = false
    @State private var navigateToLoginOnDismiss = false
    @State private var currentNonce: String? = nil
    @State private var authBusy = false

    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @StateObject private var appleAuth = AppleAuthManager()
    @State private var showIntro = false
    @FocusState private var registerFocus: RegisterField?

    private enum RegisterField { case email, password }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minL = min(w, h)

                let sectionGap = h * 0.075
                let fieldGap = minL * 0.030
                let socialGap = minL * 0.035

                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)

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
                                Text("Create Your Space")
                                    .font(AlynnaTypography.font(.title3))
                                    .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.9))
                            }
                            .padding(.top, h * 0.01)
                            .staggered(1, show: $showIntro)
                        }
                        .padding(.top, h * 0.05)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        VStack(spacing: fieldGap) {
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
                                Text("Create Account")
                                    .font(AlynnaTypography.font(.headline))
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

                        VStack(spacing: socialGap) {
                            HStack {
                                Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                                Text("Or with")
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                            }
                            .staggered(5, show: $showIntro)

                            VStack(spacing: minL * 0.025) {
                                Text("Google may show \"Sign in\" — if you're new, we'll create your account.")
                                    .font(AlynnaTypography.font(.footnote))
                                    .foregroundColor(themeManager.fixedNightTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 6)
                                    .staggered(6, show: $showIntro)

                                Button(action: {
                                    guard !authBusy else { return }
                                    authBusy = true
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    if !GoogleSignInDiagnostics.preflight(context: "SignUpView.GoogleButton") {
                                        authBusy = false
                                        alertMessage = ""
                                        showAlert = true
                                        return
                                    }

                                    handleGoogleFromRegister(
                                        onNewUserGoOnboarding: {
                                            authBusy = false
                                            shouldOnboardAfterSignIn = true
                                            navigateToOnboarding = true
                                        },
                                        onExistingUserGoLogin: { msg in
                                            authBusy = false
                                            shouldOnboardAfterSignIn = false
                                            infoMessage = msg
                                            navigateToLoginOnDismiss = true
                                            showInfoAlert = true
                                        },
                                        onError: { message in
                                            authBusy = false
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = message
                                            showAlert = true
                                        }
                                    )
                                }) {
                                    HStack(spacing: 12) {
                                        Image("googleIcon")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                        Text("Sign up with Google")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                }
                                .disabled(authBusy)
                                .staggered(8, show: $showIntro)

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
                                                    shouldOnboardAfterSignIn = true
                                                    navigateToOnboarding = true
                                                }
                                            },
                                            onExistingUserGoLogin: { msg in
                                                DispatchQueue.main.async {
                                                    authBusy = false
                                                    shouldOnboardAfterSignIn = false
                                                    infoMessage = msg
                                                    navigateToLoginOnDismiss = true
                                                    showInfoAlert = true
                                                }
                                            },
                                            onError: { message in
                                                DispatchQueue.main.async {
                                                    authBusy = false
                                                    shouldOnboardAfterSignIn = false
                                                    alertMessage = message
                                                    showAlert = true
                                                }
                                            }
                                        )
                                    }
                                )
                                .frame(height: 50)
                                .signInWithAppleButtonStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .disabled(authBusy)
                                .staggered(8, show: $showIntro)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: h * 0.08)
                    }
                    .preferredColorScheme(.dark)
                    .transaction { $0.animation = nil }
                }
                .hideKeyboardOnTapOutside($registerFocus)
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
                .onAppear {
                    showIntro = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        registerFocus = .email
                    }
                    _ = GoogleSignInDiagnostics.run(context: "SignUpView.onAppear")
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

    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }

        hasCompletedOnboarding = false
        isLoggedIn = false
        shouldOnboardAfterSignIn = true

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                if let errCode = AuthErrorCode(rawValue: error._code),
                   errCode == .emailAlreadyInUse {
                    shouldOnboardAfterSignIn = false
                    isLoggedIn = false
                    hasCompletedOnboarding = false

                    infoMessage = "This email is already in use. Please sign in instead."
                    navigateToLoginOnDismiss = true
                    showInfoAlert = true
                    return
                }

                alertMessage = error.localizedDescription
                showAlert = true
                return
            }

            result?.user.sendEmailVerification(completion: nil)
            DispatchQueue.main.async {
                navigateToOnboarding = true
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
