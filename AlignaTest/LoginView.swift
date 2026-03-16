import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import FirebaseCore

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
    @State private var currentNonce: String? = nil
    @State private var navigateToHome = false
    @State private var authBusy = false
    @State private var showIntro = false
    @FocusState private var loginFocus: LoginField?
    private enum LoginField { case email, password }
    private var panelBG: Color { Color.white.opacity(0.10) }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(mode: .night)
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
                            Text("Welcome Back")
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

                                if let user = Auth.auth().currentUser, !user.isEmailVerified {
                                    user.sendEmailVerification(completion: nil)
                                    try? Auth.auth().signOut()
                                    alertMessage = "Please verify your email before continuing. We just sent you a new verification email."
                                    showAlert = true
                                    return
                                }

                                routeAuthenticatedUser(
                                    onSuccessToLogin: {
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        infoMessage = "We found your account, but a few details are missing. Let’s finish setup."
                                        dismissAfterInfo = true
                                        showInfoAlert = true
                                    },
                                    onError: { message in
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }
                        }) {
                            HStack(spacing: 8) {
                                if authBusy {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.black)
                                        .scaleEffect(0.75)
                                }
                                Text(authBusy ? "Signing in..." : "Log In")
                            }
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
                            Text("Or with")
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
                                        infoMessage = "We found your account, but a few details are missing. Let’s finish setup."
                                        dismissAfterInfo = true
                                        showInfoAlert = true
                                    },
                                    onError: { message in
                                        authBusy = false
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }) {
                                HStack(spacing: 12) {
                                    if authBusy {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(themeManager.fixedNightTextPrimary)
                                            .scaleEffect(0.75)
                                    }
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text("Sign in with Google")
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
                                            infoMessage = "We found your account, but a few details are missing. Let’s finish setup."
                                            dismissAfterInfo = true
                                            showInfoAlert = true
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
                            .overlay(alignment: .leading) {
                                if authBusy {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.black)
                                        .scaleEffect(0.75)
                                        .padding(.leading, 16)
                                }
                            }
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
                                Text("Create An Account")
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
            .alert("Almost there", isPresented: $showInfoAlert) {
                Button("Continue") {
                    if dismissAfterInfo {
                        dismissAfterInfo = false
                        dismiss()
                    }
                }
            } message: {
                Text(infoMessage)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
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

