import SwiftUI

struct UserInfo: Codable {
    var dob: String
    var birth_place: String
    var birth_time: String
    var current_location: String
}

struct AccountDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var userInfo = UserInfo(
        dob: "",
        birth_place: "",
        birth_time: "",
        current_location: ""
    )

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minLength = min(width, height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                VStack(spacing: height * 0.04) {
                    Text("Account")
                        .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.10))
                        .foregroundColor(themeManager.foregroundColor)
                        .padding(.top, height * 0.05)

                    VStack(alignment: .leading, spacing: height * 0.04) {
                        Text("Information")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.06))
                            .foregroundColor(themeManager.foregroundColor)

                        infoRow(title: "Date of Birth", value: userInfo.dob, width: width)
                        infoRow(title: "Place of Birth", value: userInfo.birth_place, width: width)
                        infoRow(title: "Time of Birth", value: userInfo.birth_time, width: width)
                        infoRow(title: "Current Location", value: userInfo.current_location, width: width)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeManager.foregroundColor.opacity(0.7), lineWidth: 1)
                    )
                    .padding(.horizontal, width * 0.1)

                    Spacer()
                }
            }
            .onAppear {
                starManager.animateStar = true
                themeManager.updateTheme()
                fetchUserInfo(userId: "user123") { user in
                    if let user = user {
                        self.userInfo = user
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(themeManager.foregroundColor.opacity(0.6))

            Text(value)
                .font(.body)
                .foregroundColor(.black)
                .frame(width: width * 0.8, height: 44)
                .background(themeManager.foregroundColor)
                .cornerRadius(10)
        }
    }

    private func fetchUserInfo(userId: String, completion: @escaping (UserInfo?) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:8000/user/\(userId)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            let decoder = JSONDecoder()
            if let user = try? decoder.decode(UserInfo.self, from: data) {
                DispatchQueue.main.async {
                    completion(user)
                }
            }
        }.resume()
    }
}

#Preview {
    AccountDetailView()
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
}
