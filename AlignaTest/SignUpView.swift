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
    @State private var navigateToOnboarding = false
    @State private var navigateToLogin = false
    @State private var currentNonce: String? = nil

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
                                Text("Create Your Space")
                                    .font(.custom("Merriweather-Bold", size: 28))
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

                        VStack(spacing: socialGap) {
                            Text("Or continue with")
                                .font(AlignaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                                .staggered(5, show: $showIntro)

                            HStack(spacing: minL * 0.10) {
                                Button(action: {
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    if !GoogleSignInDiagnostics.preflight(context: "SignUpView.GoogleButton") {
                                        alertMessage = ""
                                        showAlert = true
                                        return
                                    }

                                    handleGoogleFromRegister(
                                        onNewUserGoOnboarding: {
                                            shouldOnboardAfterSignIn = true
                                            navigateToOnboarding = true
                                        },
                                        onExistingUserGoLogin: { msg in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = msg
                                            showAlert = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                navigateToLogin = true
                                            }
                                        },
                                        onError: { message in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = message
                                            showAlert = true
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

                                Button {
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    let nonce = randomNonceString()
                                    currentNonce = nonce
                                    appleAuth.startSignUp(nonce: nonce) { result in
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
                    .transaction { $0.animation = nil }
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

                    alertMessage = "This email is already in use. Redirecting to Sign In..."
                    showAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        navigateToLogin = true
                    }
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
