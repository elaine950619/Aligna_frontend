import SwiftUI

struct FirstPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                ZStack {
                    // 背景组件
                    AppBackgroundView()
                        .environmentObject(starManager)

                    VStack(spacing: minLength * 0.015) {
                        // 顶部按钮
                        HStack {
                            NavigationLink(
                                destination: ContentView()
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                            ) {
                                Rectangle()
                                    .fill(themeManager.foregroundColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("T")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    )
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)

                            Spacer()

                            HStack(spacing: geometry.size.width * 0.04) {
                                NavigationLink(destination: SettingPageView()) {
                                    Image("setting")
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(themeManager.foregroundColor)
                                }

                                NavigationLink(destination: AccountPageView()) {
                                    Image("account")
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(themeManager.foregroundColor)
                                }
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)
                        }

                        Text("Aligna")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.13))
                            .foregroundColor(themeManager.foregroundColor)

                        Text("Align to the rhythm of this place and open yourself to its guidance.")
                            .font(Font.custom("PlayfairDisplay-Italic", size: minLength * 0.04))
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            .padding(.horizontal, geometry.size.width * 0.1)
                        
                        Spacer()

                        VStack(spacing: minLength * 0.05) {
                            let columns = [
                                GridItem(.flexible(), alignment: .center),
                                GridItem(.flexible(), alignment: .center)
                            ]

                            LazyVGrid(columns: columns, spacing: geometry.size.height * 0.03) {
                                navItemView(icon: "icon_place", title: "Place", geometry: geometry)
                                navItemView(icon: "icon_gemstone", title: "Gemstone", geometry: geometry)
                                navItemView(icon: "icon_color", title: "Color", geometry: geometry)
                                navItemView(icon: "icon_scent", title: "Scent", geometry: geometry)
                                navItemView(icon: "icon_activity", title: "Activity", geometry: geometry)
                                navItemView(icon: "icon_sound", title: "Sound", geometry: geometry)
                                navItemView(icon: "icon_career", title: "Career", geometry: geometry)
                                navItemView(icon: "icon_relationship", title: "Relationship", geometry: geometry)
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)
                        }

                        Spacer()
                        Spacer().frame(height: geometry.size.height * 0.03)
                    }
                }
                .onAppear {
                    starManager.animateStar = true
                    themeManager.updateTheme()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func navItemView(icon: String, title: String, geometry: GeometryProxy) -> some View {
        NavigationLink(
            destination: RecommendationDetailView(
                
                category: firebaseCollectionName(for: title),
                documentName: viewModel.recommendations[title] ?? ""  // ✅ 正确读取推荐值
            )
        ) {
            VStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * 0.20)
                    .foregroundColor(themeManager.foregroundColor)

                Text(title)
                    .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.055))
                    .foregroundColor(themeManager.foregroundColor)
            }
        }
    }
}
import FirebaseFirestore
import FirebaseAuth
import MapKit

class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var gender: String = ""
    @Published var birth_date: Date = Date()
    @Published var birth_time: Date = Date()
    @Published var birthPlace: String = ""
    @Published var currentPlace: String = ""
    @Published var birthCoordinate: CLLocationCoordinate2D?
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var recommendations: [String: String] = [:]

}

struct OnboardingStep1: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Your Nickname")
                .font(.title)
            TextField("Text your name here", text: $viewModel.nickname)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Text("Gender")
                .font(.title)
            Picker("", selection: $viewModel.gender) {
                Text("Male").tag("Male")
                Text("Female").tag("Female")
                Text("Other").tag("Other")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            NavigationLink("NEXT") {
                OnboardingStep2(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Welcome")
    }
}

struct OnboardingStep2: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Your Birthday")
                .font(.title)
            DatePicker("", selection: $viewModel.birth_date, displayedComponents: [.date])
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
            
            Text("Time of Your Birth")
                .font(.title)
            DatePicker("", selection: $viewModel.birth_time, displayedComponents: [.hourAndMinute])
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
            
            NavigationLink("NEXT") {
                OnboardingStep3(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("生日 & 时间")
    }
}

struct OnboardingStep3: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var birthSearch = ""
    @State private var currentSearch = ""
    @State private var birthResults: [MKLocalSearchCompletion] = []
    @State private var currentResults: [MKLocalSearchCompletion] = []

    @StateObject private var searchDelegate = SearchDelegate()
    class CompleterWrapper {
        let completer = MKLocalSearchCompleter()
    }
    @State private var completerWrapper = CompleterWrapper()
    private var searchCompleter: MKLocalSearchCompleter { completerWrapper.completer }
    @State private var isSearchingBirth = true

    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 20) {
                    Group {
                        Text("Place of Birth").font(.title)
                        TextField("Your Birth Place", text: $birthSearch)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: birthSearch) { oldVal, newVal in
                                if newVal != currentSearch {  // 🔁 确保不是 currentPlace 触发的
                                    isSearchingBirth = true
                                    searchCompleter.queryFragment = newVal
                                }
                            }
                        ForEach(birthResults, id: \.self) { result in
                            Button(result.title) {
                                resolveLocation(for: result, isBirth: true)
                            }
                        }
                    }
                    
                    Group {
                        Text("Current Place of Living").font(.title)
                        TextField("Your Current Place", text: $currentSearch)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: currentSearch) { oldVal, newVal in
                                if newVal != birthSearch {  // 🔁 确保不是 birthPlace 触发的
                                    isSearchingBirth = false
                                    searchCompleter.queryFragment = newVal
                                }
                            }
                        ForEach(currentResults, id: \.self) { result in
                            Button(result.title) {
                                resolveLocation(for: result, isBirth: false)
                            }
                        }
                    }
                    
                    NavigationLink("NEXT") {
                        OnboardingFinalStep(viewModel: viewModel)
                    }
                    .padding()
                }
                .onAppear {
                    searchCompleter.resultTypes = [.address]
                    searchCompleter.delegate = searchDelegate
                    
                    searchDelegate.onResults = { results in
                        if isSearchingBirth {
                            birthResults = results
                        } else {
                            currentResults = results
                        }
                    }
                }
                
                .navigationTitle("地点")
            }
        }
    }

    private func resolveLocation(for completion: MKLocalSearchCompletion, isBirth: Bool) {
        print("Start resolving location for \(completion.title)")
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        search.start { response, error in
            guard let item = response?.mapItems.first else {
                print("⚠️ 无法解析位置：\(error?.localizedDescription ?? "未知错误")")
                return
            }
            let placemark = item.placemark
            let cityName = placemark.locality ?? item.name ?? completion.title

            if isBirth {
                viewModel.birthPlace = cityName
                viewModel.birthCoordinate = placemark.coordinate
                birthSearch = cityName
                print("✅ 选中出生地：\(cityName)")
            } else {
                viewModel.currentPlace = cityName
                viewModel.currentCoordinate = placemark.coordinate
                currentSearch = cityName
                print("✅ 选中当前地：\(cityName)")
            }
        }
    }

}

class SearchDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    var onResults: ([MKLocalSearchCompletion]) -> Void = { _ in }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }
}



import FirebaseFirestore
import FirebaseAuth

struct OnboardingFinalStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @State private var navigateToHome = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Confirm Your Information").font(.title)
            Text("Nickname: \(viewModel.nickname)")
            Text("Gender: \(viewModel.gender)")
            Text("Birthday: \(viewModel.birth_date.formatted(date: .abbreviated, time: .omitted))")
            Text("Time: \(viewModel.birth_time.formatted(date: .omitted, time: .shortened))")
            Text("Place of Birth: \(viewModel.birthPlace)")
            Text("Current Place of Living: \(viewModel.currentPlace)")
            
            Button("Confirm") {
                print("button pressed")
                uploadUserInfo()
            }
            
            .padding()
        }
        .navigationDestination(isPresented: $navigateToHome) {
            FirstPageView()
        }
        .navigationTitle("完成")
    }
    
    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""

    private func uploadUserInfo() {
        print("🚀 uploadUserInfo triggered")
        if Auth.auth().currentUser == nil {
               Auth.auth().signInAnonymously { result, error in
                   if let error = error {
                       print("❌ 匿名登录失败: \(error)")
                   } else {
                       print("✅ 匿名登录成功")
                       uploadUserInfo() // 登录成功后再调用一次
                   }
               }
               return
           }

           guard let userId = Auth.auth().currentUser?.uid else {
               print("❌ 依然无法获取 UID")
               return
           }

           print("📡 starting Firestore setData...")

            let db = Firestore.firestore()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

            let birthDateString = dateFormatter.string(from: viewModel.birth_date)
            let birthTimeString = timeFormatter.string(from: viewModel.birth_time)
            let lat = viewModel.currentCoordinate?.latitude ?? 0
            let lng = viewModel.currentCoordinate?.longitude ?? 0
           let data: [String: Any] = [
               "nickname": viewModel.nickname,
               "gender": viewModel.gender,
               "birthDate": birthDateString,
               "birthTime": birthTimeString,
               "birthPlace": viewModel.birthPlace,
               "currentPlace": viewModel.currentPlace,
               "birthLat": viewModel.birthCoordinate?.latitude ?? 0,
               "birthLng": viewModel.birthCoordinate?.longitude ?? 0,
               "currentLat": lat,
               "currentLng": lng,
               "createdAt": Timestamp()
           ]

           db.collection("users").document(userId).setData(data) { error in
               if let error = error {
                   print("❌ Firebase 上传失败: \(error)")
               } else {
                   print("✅ Firebase 上传成功")
                   hasCompletedOnboarding = true
                   navigateToHome = true
               }
           }

        

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        guard let url = URL(string: "https://aligna-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            return
        }

        print("📡 正在发送请求到 FastAPI...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                return
            }

            guard let data = data, var rawString = String(data: data, encoding: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                return
            }

            print("📩 FastAPI 原始返回: \(rawString)")


            guard let cleanedData = rawString.data(using: .utf8) else {
                print("❌ 字符串转 Data 失败")
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String] {
                    DispatchQueue.main.async {
                        viewModel.recommendations = recs
                        print("✅ 成功保存推荐结果：\(recs)")
                        navigateToHome = true
                    }
                } else {
                    print("❌ JSON 解包失败或缺失 recommendations 字段")
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
            }
        }.resume()
    }

}

func firebaseCollectionName(for category: String) -> String {
    let mapping: [String: String] = [
        "Place": "places",
        "Gemstone": "gemstones",
        "Color": "colors",
        "Scent": "scents",
        "Activity": "activities",
        "Sound": "sounds",
        "Career": "careers",
        "Relationship": "relationships"
    ]
    return mapping[category] ?? ""
}




// Hex Color 支持
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    FirstPageView()
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
}



struct ContentView_Previews:
    PreviewProvider {
        static var previews: some View {
            OnboardingFinalStep(viewModel: OnboardingViewModel())
        }
}
