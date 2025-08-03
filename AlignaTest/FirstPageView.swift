import SwiftUI

struct FirstPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @StateObject private var locationManager = LocationManager()
  
    @State private var selectedDate = Date()

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
                            
                            NavigationLink(
                                destination: JournalView(date: selectedDate)
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                            ) {
                                Rectangle()
                                    .fill(themeManager.foregroundColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("+")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    )
                            }
//                            .padding(.horizontal, geometry.size.width * 0.05)

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

                        Text(viewModel.dailyMantra)
                            .font(Font.custom("PlayfairDisplay-Italic", size: minLength * 0.04))
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            .padding(.horizontal, geometry.size.width * 0.1)

                        Spacer()
                        // Jornaling button
//                        NavigationLink {
//                            JournalView(date: selectedDate)
//                        } label: {
//                            Text("Have something to say?")
//                              .font(.subheadline)
//                              .padding(.vertical, 8)
//                              .padding(.horizontal, 16)
//                              .background(Capsule().fill(accent.opacity(0.2)))
//                              .foregroundColor(accent)
//                        }

                        VStack(spacing: minLength * 0.05) {
                            if viewModel.recommendations.isEmpty {
                                    ProgressView("Loading your personalized guidance...")
                                        .foregroundColor(themeManager.foregroundColor)
                                        .padding()
                            } else {
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
                        }

                        Spacer()
                        Spacer().frame(height: geometry.size.height * 0.03)
                    }
                    .padding(.top, 16)
                }
                .onAppear {
                    starManager.animateStar = true
                    themeManager.updateTheme()
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let today = dateFormatter.string(from: Date())
                    
                    print("🧠 当前推荐：\(viewModel.recommendations)") // ✅ 如果是空的，就是没传过来
                    if viewModel.recommendations.isEmpty || lastRecommendationDate != today {
                        locationManager.requestLocation()
                        fetchAndSaveRecommendationIfNeeded()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func fetchAndSaveRecommendationIfNeeded() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 用户未登录，跳过获取推荐")
            return
        }

        let db = Firestore.firestore()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: today)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 查询推荐失败：\(error)")
                    return
                }

                guard let snapshot = snapshot else {
                    print("❌ 查询 snapshot 为 nil")
                    return
                }

                if !snapshot.documents.isEmpty {
                    print("📌 今日已有推荐，跳过生成")
                    loadTodayRecommendation()
                    lastRecommendationDate = today
                    return
                }

                // 👇 如果没有推荐，等定位获取后调用后端
                if let coord = locationManager.currentLocation {
                    fetchFromFastAPIAndSave(coord: coord, userId: userId, today: today)
                } else {
                    print("⏳ 等待定位完成后再发请求")
                }
            }
    }
    
    private func fetchFromFastAPIAndSave(coord: CLLocationCoordinate2D, userId: String, today: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": coord.latitude,
            "longitude": coord.longitude
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let rawString = String(data: data, encoding: .utf8),
                  let jsonData = rawString.data(using: .utf8) else {
                print("❌ FastAPI 响应格式错误")
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantra = parsed["mantra"] as? String {
                    DispatchQueue.main.async {
                        viewModel.recommendations = recs
                        viewModel.dailyMantra = mantra
                        lastRecommendationDate = today

                        var recommendationData: [String: Any] = recs
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = today
                        recommendationData["mantra"] = mantra

                        let db = Firestore.firestore()
                        db.collection("daily_recommendation").addDocument(data: recommendationData) { error in
                            if let error = error {
                                print("❌ 保存 daily_recommendation 失败：\(error)")
                            } else {
                                print("✅ 推荐结果已保存")
                            }
                        }
                    }
                }
            } catch {
                print("❌ FastAPI 响应解析失败: \(error)")
            }
        }.resume()
    }



    private func navItemView(icon: String, title: String, geometry: GeometryProxy) -> some View {
        let documentName = viewModel.recommendations[title] ?? ""

        return Group {
            if !documentName.isEmpty {
                NavigationLink(destination:
                       viewForCategory(title: title, documentName: documentName)
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
            } else {
                Button {
                    print("⚠️ 无法进入 '\(title)'，推荐结果尚未加载")
                } label: {
                    VStack(spacing: 8) {
                        Image(icon)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width * 0.20)
                            .foregroundColor(themeManager.foregroundColor)

                        Text(title)
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.055))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func viewForCategory(title: String, documentName: String) -> some View {
        switch title {
        case "Place":
            PlaceDetailView(documentName: documentName)
//            imageNames:
        case "Gemstone":
            GemstoneDetailView(documentName: documentName)
        case "Color":
            ColorDetailView(documentName: documentName)
        case "Scent":
            ScentDetailView(documentName: documentName)
        case "Activity":
            ActivityDetailView(documentName: documentName)
        case "Sound":
            SoundDetailView(documentName: documentName)
        case "Career":
            CareerDetailView(documentName: documentName)
        case "Relationship":
            RelationshipDetailView(documentName: documentName)
        default:
            Text("⚠️ Unknown Category")
        }
    }


    private func loadTodayRecommendation() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法获取推荐")
            return
        }

        let db = Firestore.firestore()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: today)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 查询推荐失败：\(error)")
                    return
                }

                guard let documents = snapshot?.documents, let doc = documents.first else {
                    print("⚠️ 今日暂无推荐数据")
                    return
                }

                var recs: [String: String] = [:]
                var fetchedMantra = ""
                
                for (key, value) in doc.data() {
                    if key == "mantra", let mantraText = value as? String {
                        fetchedMantra = mantraText
                    } else if key != "uid" && key != "createdAt", let str = value as? String {
                        recs[key] = str
                    }
                }

                DispatchQueue.main.async {
                    self.viewModel.recommendations = recs
                    self.viewModel.dailyMantra = fetchedMantra
                    print("✅ 成功加载今日推荐：\(recs)")
                }
            }
    }
}

import SwiftUI
import FirebaseFirestore
import AVFoundation

struct SoundDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?
    @StateObject private var soundPlayer = SoundPlayer()

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Sound
                Text("Sound")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image + Play Button Side by Side
                    HStack(alignment: .center, spacing: 20) {
                        Image(documentName) // assumes .png in assets with name matching documentName
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(themeManager.accent)
                        
                        Button(action: {
                            soundPlayer.playSound(named: documentName)
                        }) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                Text("Play")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("sounds").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

struct IconItem: Identifiable {
  let id = UUID()
  let imageName: String
  let title: String
}

struct PlaceDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
//    let imageNames: [String]
    let iconItems = [
        IconItem(imageName: "botanical_garden", title: "Botanical\ngardens"),
        IconItem(imageName: "small_parks",     title: "Small\nparks"),
        IconItem(imageName: "shaded_paths",    title: "Shaded\npaths")
      ]
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Place
                Text("Place")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
              
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()

                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                  
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)

                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                    
                    // three images
//                    if !imageNames.isEmpty {
//                        ScrollView(.horizontal, showsIndicators: false) {
//                            HStack(spacing: 12) {
//                                ForEach(imageNames, id: \.self) { name in
//                                    Image(name)
//                                        .resizable()
//                                        .scaledToFill()
//                                        .frame(width: 140, height: 140)
//                                        .clipped()
//                                        .cornerRadius(8)
//                                }
//                            }
//                            .padding(.horizontal)
//                        }
//                        .frame(height: 160)
//                    }
                    
                    VStack(spacing: 24) {
                      // top two
                        HStack(spacing: 40) {
                            ForEach(iconItems[1...2]) { item in
                                VStack(spacing: 8) {
                                    Image(item.imageName)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(themeManager.accent)
                                    Text(item.title)
                                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(themeManager.accent)
                                        .fixedSize(horizontal: true, vertical: true)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 60)
                            }
                        }
                        
                        // bottom icon
                        VStack(spacing: 8) {
                            Image(iconItems[0].imageName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(themeManager.accent)
                            Text(iconItems[0].title)
                                .font(.custom("PlayfairDisplay-Regular", size: 16))
                                .multilineTextAlignment(.center)
                                .foregroundColor(themeManager.accent)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                        }
                    }
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("places").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

import SwiftUI
import FirebaseFirestore

struct GemstoneDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            VStack(spacing: 20) {
                // Gemstone
                Text("Gemstone")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                    
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("gemstones").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

struct ColorDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Color
                Text("Color")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("colors").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

struct ScentDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            VStack(spacing: 20) {
                // Scent
                Text("Scent")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("scents").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

struct ActivityDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Activity
                Text("Activity")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("activities").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}

struct CareerDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Career
                Text("Career")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("careers").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}


struct RelationshipDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            VStack(spacing: 20) {
                // Relationship
                Text("Relationship")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                
                if let item = item {
                    // Title
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.accent)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.bodyText)
                    
                    // three images
                    
                } else {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                }
            }
            .padding()
            .onAppear {
                fetchItem()
            }
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("relationships").document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
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
    @Published var dailyMantra: String = ""

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

import SwiftUI
import MapKit
import CoreLocation

struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(subtitle)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}
import SwiftUI
import MapKit
import CoreLocation

struct OnboardingStep3: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var birthSearch = ""
    @State private var birthResults: [PlaceResult] = []
    @State private var didSelectBirth = false

    @StateObject private var locationManager = LocationManager()
    @State private var didResolveCurrent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 出生地选择
                    Group {
                        Text("Place of Birth").font(.title)

                        TextField("Your Birth Place", text: $birthSearch)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: birthSearch) { _, newVal in
                                if !didSelectBirth && !newVal.isEmpty {
                                    performBirthSearch(query: newVal)
                                }
                                didSelectBirth = false
                            }

                        if !viewModel.birthPlace.isEmpty {
                            Text("✓ Selected: \(viewModel.birthPlace)")
                                .foregroundColor(.green)
                        }

                        ForEach(birthResults) { result in
                            Button {
                                viewModel.birthPlace = result.name
                                viewModel.birthCoordinate = result.coordinate
                                birthSearch = result.name
                                birthResults = []
                                didSelectBirth = true
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.name).bold()
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(hex: "#E6D9BD").opacity(0.3))
                                .cornerRadius(8)
                            }
                        }
                    }

                    Divider().padding(.vertical)

                    // 当前位置
                    Group {
                        Text("Current Place of Living").font(.title)

                        Button("📍 获取当前位置") {
                            locationManager.requestLocation()
                            didResolveCurrent = false // 允许重新解析
                        }
                        .padding()
                        .background(Color(hex: "#E6D9BD").opacity(0.3))
                        .cornerRadius(10)

                        if let coord = locationManager.currentLocation, !didResolveCurrent {
                            Text("正在反向解析地址...")
                                .onAppear {
                                    getAddressFromCoordinate(coord) { placeName in
                                        if let name = placeName {
                                            viewModel.currentPlace = name
                                            viewModel.currentCoordinate = coord
                                        }
                                        didResolveCurrent = true
                                    }
                                }
                        }

                        if !viewModel.currentPlace.isEmpty {
                            Text("✓ 当前所在地: \(viewModel.currentPlace)")
                                .foregroundColor(.green)
                        }
                    }

                    NavigationLink("NEXT") {
                        OnboardingFinalStep(viewModel: viewModel)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("地点")
        }
    }

    // MARK: - 反向地理编码
    private func getAddressFromCoordinate(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let city = placemark.locality ?? placemark.administrativeArea ?? placemark.name
                completion(city)
            } else {
                print("❌ 地址解析失败: \(error?.localizedDescription ?? "未知错误")")
                completion(nil)
            }
        }
    }

    // MARK: - 出生地搜索
    private func performBirthSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let items = response?.mapItems else {
                print("❌ Birth search failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let results = items.compactMap { item in
                PlaceResult(
                    name: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }

            DispatchQueue.main.async {
                self.birthResults = results
            }
        }
    }
}


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            DispatchQueue.main.async {
                self.currentLocation = location.coordinate
            }
            manager.stopUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.locationStatus = manager.authorizationStatus
        if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 获取位置失败: \(error.localizedDescription)")
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
                    .environmentObject(viewModel)
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
               "uid": userId,
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

            db.collection("users").addDocument(data: data) { error in
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

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
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
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantraText = parsed["mantra"] as? String {
                    DispatchQueue.main.async {
                        viewModel.recommendations = recs
                        print("✅ 成功保存推荐结果：\(recs)")
                        
                        guard let userId = Auth.auth().currentUser?.uid else {
                            print("❌ 无法获取当前用户 UID")
                            return
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let createdAt = dateFormatter.string(from: Date())

                        // 🗂️ 构建推荐结果 + UID + createdAt
                        var recommendationData: [String: Any] = recs // 包含8类推荐
                        self.mantra = mantraText
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = createdAt
                        recommendationData["mantra"] = mantraText
                        
                        // ☁️ 写入到 Firestore 的 daily_recommendation 集合
                        let db = Firestore.firestore()
                        db.collection("daily_recommendation").addDocument(data: recommendationData) { error in
                            if let error = error {
                                print("❌ 保存 daily_recommendation 失败：\(error)")
                            } else {
                                print("✅ 推荐结果保存到 daily_recommendation 成功")
                            }
                        }
                        
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


import SwiftUI
import FirebaseCore
import AuthenticationServices

struct AccountPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentNonce: String? = nil
    @State private var navigateToDetail = false



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
                                    handleGoogleLogin(viewModel: viewModel) {
                                        // 登录 & 写入成功后跳转页面
                                        // e.g., dismiss() 或 navigateToHome = true
                                        DispatchQueue.main.async {
                                            navigateToDetail = true
                                        }

                                    }
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
                                        let nonce = randomNonceString()
                                        currentNonce = nonce
                                        request.requestedScopes = [.fullName, .email]
                                        request.nonce = sha256(nonce)
                                    },
                                    onCompletion: { result in
                                        handleAppleLogin(result: result, rawNonce: currentNonce ?? "") {
                                            // 登录完成后的跳转逻辑
                                            DispatchQueue.main.async {
                                                navigateToDetail = true
                                            }
                                        }
                                    }
                                )

                                .frame(width: 140, height: 45)
                                .signInWithAppleButtonStyle(themeManager.foregroundColor == .black ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                // Facebook 登录按钮
                                Button(action: {
                                    handleTwitterLogin {
                                        // 登录完成后的跳转逻辑
                                        DispatchQueue.main.async {
                                            navigateToDetail = true
                                        }

                                    }
                                    print("Twitter login tapped")
                                    
                                    
                                }) {
                                    Image("twitterIcon")
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
            .navigationDestination(isPresented: $navigateToDetail) {
                AccountDetailView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
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

import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift

func handleGoogleLogin(viewModel: OnboardingViewModel, completion: @escaping () -> Void) {
    print("🔍 准备执行 Google 登录")
    
    guard let firebaseApp = FirebaseApp.app() else {
        print("❌ FirebaseApp 未初始化")
        return
    }
    
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        print("❌ 未获取到 Firebase clientID")
        return
    }
    print("✅ 成功获取到 clientID：\(clientID)")
    let config = GIDConfiguration(clientID: clientID)

    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        print("❌ 未找到 RootViewController")
        return
    }

    GIDSignIn.sharedInstance.configuration = config
    print("📤 开始 Google 登录流程")

    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            print("❌ Google 登录失败: \(error.localizedDescription)")
            return
        }

        print("✅ Google 登录回调成功，准备获取凭证")
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            print("❌ 无法获取 Google ID Token")
            return
        }

        let accessToken = user.accessToken.tokenString
        print("🔑 Google ID Token 和 Access Token 获取成功")

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            print("🔄 正在合并匿名账户与 Google 账户")
            currentUser.link(with: credential) { authResult, error in
                if let error = error {
                    print("❌ 合并失败: \(error.localizedDescription)")
                } else {
                    print("✅ 合并成功")
                    completion()
                }
            }
        } else {
            print("🔑 使用 Google 凭证直接登录")
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ 登录失败: \(error.localizedDescription)")
                } else {
                    print("✅ 登录成功")
                    completion()
                }
            }
        }
    }
}

func handleAppleLogin(result: Result<ASAuthorization, Error>, rawNonce: String, completion: @escaping () -> Void) {
    print("🔍 开始处理 Apple 登录结果")

    switch result {
    case .success(let authResults):
        print("✅ Apple 授权成功")
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            print("❌ Apple 登录失败: 无法获取 token")
            return
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: tokenString,
            rawNonce: rawNonce
        )

        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            print("🔄 合并匿名账户与 Apple 账户")
            currentUser.link(with: credential) { authResult, error in
                if let error = error {
                    print("❌ 合并失败: \(error.localizedDescription)")
                } else {
                    print("✅ 合并成功")
                    completion()
                }
            }
        } else {
            print("🔑 Apple 登录中")
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ 登录失败: \(error.localizedDescription)")
                } else {
                    print("✅ 登录成功")
                    completion()
                }
            }
        }

    case .failure(let error):
        print("❌ Apple 登录授权失败: \(error.localizedDescription)")
    }
}


import FirebaseAuth

func handleTwitterLogin(completion: @escaping () -> Void) {
    print("🔍 [handleTwitterLogin] 准备初始化 Twitter 登录流程")

    let provider = OAuthProvider(providerID: "twitter.com")
    print("🔧 Twitter Provider 已创建: \(provider)")

    provider.getCredentialWith(nil) { credential, error in
        print("📡 Twitter getCredentialWith 回调触发")

        if let error = error {
            print("❌ 获取 Twitter 凭证失败: \(error.localizedDescription)")
            return
        }

        guard let credential = credential else {
            print("❌ Twitter 凭证为空，登录终止")
            return
        }

        print("🔑 Twitter 凭证获取成功: \(credential.provider)")

        let currentUser = Auth.auth().currentUser
        print("👤 当前用户状态: \(currentUser?.uid ?? "无用户"), 匿名: \(currentUser?.isAnonymous == true)")

        if let user = currentUser, user.isAnonymous {
            print("🔄 正在尝试合并匿名用户与 Twitter 登录")
            user.link(with: credential) { authResult, error in
                if let error = error {
                    print("❌ Twitter 合并失败: \(error.localizedDescription)")
                } else {
                    print("✅ Twitter 合并成功: \(authResult?.user.uid ?? "未知 UID")")
                    completion()
                }
            }
        } else {
            print("🚀 正常登录流程 - 使用 Twitter 凭证登录")
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ Twitter 登录失败: \(error.localizedDescription)")
                } else {
                    print("✅ Twitter 登录成功: \(authResult?.user.uid ?? "未知 UID")")
                    completion()
                }
            }
        }
    }

    print("📨 已触发 getCredentialWith 调用，等待回调...")
}




import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfo: Codable {
    var birth_date: String
    var birthPlace: String
    var birth_time: String
    var currentPlace: String
}

struct AccountDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var userInfo = UserInfo(birth_date: "", birthPlace: "", birth_time: "", currentPlace: "")
    @State private var isLoading = true
    @State private var errorMessage = ""

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minLength = min(width, height)

            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(themeManager.foregroundColor)
                } else if !errorMessage.isEmpty {
                    Text("❌ \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    VStack(spacing: height * 0.04) {
                        Text("Account")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.10))
                            .foregroundColor(themeManager.foregroundColor)
                            .padding(.top, height * 0.05)

                        VStack(alignment: .leading, spacing: height * 0.04) {
                            Text("Information")
                                .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.06))
                                .foregroundColor(themeManager.foregroundColor)

                            infoRow(title: "Date of Birth", value: userInfo.birth_date, width: width)
                            infoRow(title: "Place of Birth", value: userInfo.birthPlace, width: width)
                            infoRow(title: "Time of Birth", value: userInfo.birth_time, width: width)
                            infoRow(title: "Current Location", value: userInfo.currentPlace, width: width)
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
            }
            .onAppear {
                starManager.animateStar = true
                themeManager.updateTheme()
                loadUserInfo()
            }
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(themeManager.foregroundColor.opacity(0.6))

            Text(value.isEmpty ? "-" : value)
                .font(.body)
                .foregroundColor(.black)
                .frame(width: width * 0.8, height: 44)
                .background(themeManager.foregroundColor)
                .cornerRadius(10)
        }
    }

    private func loadUserInfo() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "未登录用户"
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid)

        docRef.getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "获取失败: \(error.localizedDescription)"
                    isLoading = false
                    return
                }

                guard let document = document, document.exists,
                      let data = document.data() else {
                    errorMessage = "未找到用户信息"
                    isLoading = false
                    return
                }

                self.userInfo = UserInfo(
                    birth_date: data["birth_date"] as? String ?? "",
                    birthPlace: data["birthPlace"] as? String ?? "",
                    birth_time: data["birth_time"] as? String ?? "",
                    currentPlace: data["currentPlace"] as? String ?? ""
                )

                isLoading = false
            }
        }
    }
}






import CryptoKit

// 生成随机字符串 nonce
func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }

        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

// 对 nonce 做 SHA256 哈希
func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
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


import AVFoundation

class SoundPlayer: ObservableObject {
    var player: AVAudioPlayer?

    func playSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
            print("❌ 找不到音频文件：\(soundName).wav")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            print("🎵 正在播放：\(soundName).wav")
        } catch {
            print("❌ 播放失败：\(error.localizedDescription)")
        }
    }
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
        .environmentObject(OnboardingViewModel())
}



struct ContentView_Previews:
    PreviewProvider {
        static var previews: some View {
            OnboardingFinalStep(viewModel: OnboardingViewModel())
        }
}
