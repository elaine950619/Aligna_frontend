import SwiftUI

struct RegisterPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isCodeSent = false

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                // 背景动画
                AppBackgroundView()
                    .environmentObject(starManager)

                VStack {
                    // 顶部返回按钮
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

                    VStack(spacing: 20) {
                        Text("Create Account")
                            .font(.custom("PlayfairDisplay-Regular", size: 34))
                            .foregroundColor(themeManager.foregroundColor)

                        // 邮箱输入
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(themeManager.foregroundColor)

                        // 验证码输入和发送按钮
                        HStack {
                            TextField("Verification Code", text: $code)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(themeManager.foregroundColor)

                            Button(action: {
                                // 模拟发送验证码
                                isCodeSent = true
                                alertMessage = "Verification code sent to your email."
                                showAlert = true
                            }) {
                                Text("Send Code")
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "#E6D9BD").opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundColor(themeManager.foregroundColor)
                            }
                        }

                        // 密码输入
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(themeManager.foregroundColor)

                        // 注册按钮
                        Button(action: {
                            if email.isEmpty || code.isEmpty || password.isEmpty {
                                alertMessage = "Please fill in all fields."
                                showAlert = true
                            } else {
                                alertMessage = "Registration successful!"
                                showAlert = true
                                // 可以在这里连接后端注册逻辑
                            }
                        }) {
                            Text("Register")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(themeManager.foregroundColor)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    Spacer()
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

#Preview{
    RegisterPageView()
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
}
