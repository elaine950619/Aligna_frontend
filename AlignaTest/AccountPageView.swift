import SwiftUI
import AuthenticationServices

struct AccountPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(themeManager.foregroundColor)
                        }
                        .padding(.leading, geometry.size.width * 0.05)
                        .padding(.top, geometry.size.height * 0.05)

                        Spacer()
                    }

                    Spacer()
                }

                VStack(spacing: minLength * 0.03) {
                    Text("Account")
                        .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.09))
                        .foregroundColor(themeManager.foregroundColor)
                        .padding(.top, geometry.size.height * 0.07)

                    Spacer()

                    VStack(spacing: minLength * 0.04) {
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(themeManager.foregroundColor)
                            .placeholder(when: email.isEmpty) {
                                Text("Email")
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                            }

                        SecureField("", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(themeManager.foregroundColor)
                            .placeholder(when: password.isEmpty) {
                                Text("Password")
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                            }

                        Button(action: {
                            if email.isEmpty || password.isEmpty {
                                alertMessage = "Please enter both email and password."
                                showAlert = true
                            } else {
                                print("Logging in with \(email)")
                                // 登录逻辑
                            }
                        }) {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.foregroundColor)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }

                        // 社交登录按钮区域
                        VStack(spacing: minLength * 0.025) {
                            Text("Or login with")
                                .font(.footnote)
                                .foregroundColor(themeManager.foregroundColor.opacity(0.6))

                            HStack(spacing: minLength * 0.08) {
                                // Google 登录按钮
                                Button(action: {
                                    print("Google login tapped")
                                    // Google 登录逻辑
                                }) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }

                                // Apple ID 登录按钮
                                SignInWithAppleButton(
                                    .signIn,
                                    onRequest: { request in
                                        // 配置请求
                                    },
                                    onCompletion: { result in
                                        // 处理结果
                                    }
                                )
                                .frame(width: 140, height: 45)
                                .signInWithAppleButtonStyle(themeManager.foregroundColor == .black ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                // Facebook 登录按钮
                                Button(action: {
                                    print("Facebook login tapped")
                                    // Facebook 登录逻辑
                                }) {
                                    Image("facebookIcon")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }

                        // 注册和忘记密码
                        HStack {
                            NavigationLink(destination:
                                RegisterPageView()
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                            ) {
                                Text("Register")
                                    .foregroundColor(themeManager.foregroundColor)
                            }

                            Spacer()

                            Button("Forgot Password?") {
                                // 添加找回密码逻辑
                            }
                            .foregroundColor(themeManager.foregroundColor)
                        }
                        .font(.footnote)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    Spacer()
                }
            }
            .onAppear {
                starManager.animateStar = true
                themeManager.updateTheme()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - placeholder 修饰符
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

// MARK: - Preview
#Preview {
    NavigationStack {
        AccountPageView()
            .environmentObject(StarAnimationManager())
            .environmentObject(ThemeManager())
    }
}
