//import SwiftUI
//import FirebaseAuth
//
//struct RegisterPageView: View {
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var starManager: StarAnimationManager
//    @EnvironmentObject var themeManager: ThemeManager
//
//    @State private var email = ""
//    @State private var password = ""
//    @State private var showAlert = false
//    @State private var alertMessage = ""
//    @State private var navigateToAccount = false
//    @State private var isVerificationSent = false
//
//    var body: some View {
//        NavigationStack {
//            GeometryReader { geometry in
//                let minLength = min(geometry.size.width, geometry.size.height)
//
//                ZStack {
//                    AppBackgroundView()
//                        .environmentObject(starManager)
//
//                    VStack {
//                        HStack {
//                            Button(action: { dismiss() }) {
//                                Image(systemName: "chevron.left")
//                                    .font(.title2)
//                                    .foregroundColor(themeManager.foregroundColor)
//                            }
//                            .padding(.leading, geometry.size.width * 0.05)
//                            .padding(.top, geometry.size.height * 0.05)
//
//                            Spacer()
//                        }
//
//                        Spacer()
//
//                        VStack(spacing: 20) {
//                            Text("Create Account")
//                                .font(.custom("PlayfairDisplay-Regular", size: 34))
//                                .foregroundColor(themeManager.foregroundColor)
//
//                            TextField("Email", text: $email)
//                                .textContentType(.emailAddress)
//                                .keyboardType(.emailAddress)
//                                .padding()
//                                .background(Color.white.opacity(0.1))
//                                .cornerRadius(12)
//                                .foregroundColor(themeManager.foregroundColor)
//
//                            SecureField("Password", text: $password)
//                                .padding()
//                                .background(Color.white.opacity(0.1))
//                                .cornerRadius(12)
//                                .foregroundColor(themeManager.foregroundColor)
//
//                            Button(action: {
//                                registerAndSendVerification()
//                            }) {
//                                Text("Register & Send Email")
//                                    .font(.headline)
//                                    .padding()
//                                    .frame(maxWidth: .infinity)
//                                    .background(themeManager.foregroundColor)
//                                    .foregroundColor(.black)
//                                    .cornerRadius(12)
//                            }
//                        }
//                        .padding(.horizontal, geometry.size.width * 0.1)
//
//                        Spacer()
//                    }
//                }
//                .alert(isPresented: $showAlert) {
//                    Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
//                }
//                .navigationDestination(isPresented: $navigateToAccount) {
//                    AccountPageView()
//                        .environmentObject(starManager)
//                        .environmentObject(themeManager)
//                }
//            }
//        }
//    }
//
//    private func registerAndSendVerification() {
//        guard !email.isEmpty, !password.isEmpty else {
//            alertMessage = "Please fill in all fields."
//            showAlert = true
//            return
//        }
//
//        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
//            alertMessage = "No anonymous user to link with."
//            showAlert = true
//            return
//        }
//
//        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
//
//        currentUser.link(with: credential) { result, error in
//            if let error = error {
//                alertMessage = "❌ \(error.localizedDescription)"
//                showAlert = true
//            } else if let user = result?.user {
//                user.sendEmailVerification(completion: { err in
//                    if let err = err {
//                        alertMessage = "Failed to send verification email: \(err.localizedDescription)"
//                        showAlert = true
//                    } else {
//                        alertMessage = "✅ Verification email sent. Please check your inbox."
//                        showAlert = true
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            navigateToAccount = true
//                        }
//                    }
//                })
//            }
//        }
//    }
//}
//
//#Preview {
//    RegisterPageView()
//        .environmentObject(StarAnimationManager())
//        .environmentObject(ThemeManager())
//}
