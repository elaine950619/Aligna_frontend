import SwiftUI

struct FirstPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    
    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
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
                            
                            Spacer()
                            
                            HStack(spacing: geometry.size.width * 0.04) {
                                if isLoggedIn {
                                    NavigationLink(destination: AccountDetailView()
                                        .environmentObject(starManager)
                                        .environmentObject(themeManager)) {
                                            Image("account")
                                                .resizable()
                                                .renderingMode(.template)
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 28, height: 28)
                                                .foregroundColor(themeManager.foregroundColor)
                                        }
                                } else {
                                    NavigationLink(destination: AccountDetailView()) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.foregroundColor)
                                    }
                                }
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)
                        }
                        
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
                        .offset(x:  geometry.size.width * 0.23, y: geometry.size.width * 0.09)
//                        .padding(.horizontal, geometry.size.width * 0.05)
                        
                        Text("Aligna")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.13))
                            .foregroundColor(themeManager.foregroundColor)
                        
                        Text(viewModel.dailyMantra)
                            .font(Font.custom("PlayfairDisplay-Italic", size: minLength * 0.04))
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            .padding(.horizontal, geometry.size.width * 0.1)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
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
                                
                                
                                LazyVGrid(columns: columns, spacing: geometry.size.height * 0.001) {
                                    navItemView(title: "Place", geometry: geometry)
                                    navItemView(title: "Gemstone", geometry: geometry)
                                    navItemView(title: "Color", geometry: geometry)
                                    navItemView(title: "Scent", geometry: geometry)
                                    navItemView(title: "Activity", geometry: geometry)
                                    navItemView(title: "Sound", geometry: geometry)
                                    navItemView(title: "Career", geometry: geometry)
                                    navItemView(title: "Relationship", geometry: geometry)
                                }
                                .padding(.horizontal, geometry.size.width * 0.05)
                            }
                        }
                        
//                        Spacer()
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
                    
                    print("🧠 当前推荐：\(viewModel.recommendations)")
                    
                    if viewModel.recommendations.isEmpty || lastRecommendationDate != today {
                        locationManager.requestLocation()
                        fetchAndSaveRecommendationIfNeeded()
                    } else {
                        // ✅ 登录后推荐已存在时也补充 fetch 标题
                        fetchAllRecommendationTitles()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationViewStyle(.stack)
    }
    private func fetchAllRecommendationTitles() {
        for (category, documentName) in viewModel.recommendations {
            let collection = firebaseCollectionName(for: category)
            let db = Firestore.firestore()
            
            db.collection(collection).document(documentName).getDocument { snapshot, error in
                if let error = error {
                    print("❌ 加载 \(category) 标题失败: \(error)")
                    return
                }
                
                if let data = snapshot?.data(), let title = data["title"] as? String {
                    DispatchQueue.main.async {
                        recommendationTitles[category] = title
                    }
                }
            }
        }
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
                        
                        // ⏱ 添加这句代码，确保写入后再 fetch title
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fetchAllRecommendationTitles()
                        }
                        
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
    
    
    
    private func navItemView(title: String, geometry: GeometryProxy) -> some View {
        let documentName = viewModel.recommendations[title] ?? ""
        
        return Group {
            if !documentName.isEmpty {
                NavigationLink(destination:
                                viewForCategory(title: title, documentName: documentName)
                ) {
                    VStack(spacing: 6) {
                        // 图标图像
                        Image(documentName)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: geometry.size.width * 0.20)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 2)
                        
                        // 推荐名称（小字体）
                        Text(recommendationTitles[title] ?? "")
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.035))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        // 类别标题
                        Text(title)
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.055))
                            .foregroundColor(themeManager.foregroundColor)
                    }
                }
            } else {
                Button {
                    print("⚠️ 无法进入 '\(title)'，推荐结果尚未加载")
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "questionmark.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.20)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                        
                        Text("Loading")
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.035))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                        
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
                    fetchAllRecommendationTitles()
                    
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

struct Glow: ViewModifier {
  var color: Color = .white
  var radius: CGFloat = 8

  func body(content: Content) -> some View {
    content
      // first, a tight glow…
      .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
      // …then a wider, fainter glow
      .shadow(color: color.opacity(0.4), radius: radius * 2, x: 0, y: 0)
  }
}

extension View {
  func glow(color: Color = .white, radius: CGFloat = 8) -> some View {
    self.modifier(Glow(color: color, radius: radius))
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
    
    @Environment(\.dismiss) private var dismiss
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
            
        }
        .onAppear { // where should i put this?
            fetchItem()
        }
        .navigationBarBackButtonHidden(true)
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
        .navigationBarBackButtonHidden(true)
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

struct BreathingCircle: View {
    let color: Color
    let diameter: CGFloat      // overall diameter
    let duration: Double   // one full in-out cycle

    @State private var animateRing = false

    var body: some View {
        ZStack {
            // Outer ring that expands/fades
            Circle()
                .stroke(color, lineWidth: diameter * 0.03)
                .frame(width: diameter, height: diameter)
                .scaleEffect(animateRing ? 1.0 : 0.7)
                .opacity(animateRing ? 0.0 : 1.0)  // fades out as it expands

            // Solid center dot
            Circle()
                .fill(color)
                .frame(width: diameter * 0.8, height: diameter * 0.8)
                .scaleEffect(animateRing ? 0.8 : 1.0)
                .opacity(animateRing ? 0.5 : 1.0)
        }
        .onAppear {
            // loop forever, no reverse (so ring just pops, fades, then pops again)
            withAnimation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
            ) {
                animateRing = true
            }
        }
    }
}

struct SetColorButton: View {
    let action: ()->Void

    var body: some View {
        Button(action: action) {
            Text("Set as Today’s Color")
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 53)
                .background(.ultraThinMaterial)        // frosted-glass
                .background(Color("ForestGreen"))       // your accent color
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ColorDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    let documentName: String
    @State private var item: RecommendationItem?
    
    // color mapping
    private let colorHexMapping: [String:String] = [
        "amber":     "#FFBF00",
        "cream":     "#FFFDD0",
        "forest_green":"#228B22",
        "ice_blue":  "#ADD8E6",
        "indigo":    "#4B0082",
        "rose":      "#FF66CC",
        "sage_green":"#9EB49F",
        "silver_white":"#C0C0C0",
        "slate_blue":"#6A5ACD",
        "teal":      "#008080"
    ]
    
    var body: some View {
        ZStack{
            AppBackgroundView()
                .environmentObject(starManager)
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
                    // Description
                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    // breathing circle
                    if let hex = colorHexMapping[item.name] {
                        BreathingCircle(
                            color: Color(hex: hex),
                            diameter: 230,
                            duration: 4
                        )
                        .padding(.top, 32)
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
                    
                    // Image
                    Image(documentName) // assumes .png in Assets
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.foregroundColor)
                    
                    // button
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
        .navigationBarBackButtonHidden(true)
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
        .navigationBarBackButtonHidden(true)
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
        .navigationBarBackButtonHidden(true)
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
            VStack(spacing: 20) {
                // Career
                Text("Career")
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
                        .glow(color: themeManager.primaryText, radius: 6)
                    
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
        .navigationBarBackButtonHidden(true)
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
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )
            
            VStack(spacing: 20) {
                // Relationship
                Text("Relationship")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()
                    .glow(color: themeManager.primaryText, radius: 6)
                
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
                        .foregroundColor(themeManager.foregroundColor)
                    
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
        .navigationBarBackButtonHidden(true)
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





// Back button

struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    var iconSize: CGFloat = 20
    var paddingSize: CGFloat = 10
    var backgroundColor: Color = Color.black.opacity(0.3)
    var iconColor: Color = .white
    var topPadding: CGFloat = 44
    var horizontalPadding: CGFloat = 24
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(iconColor)
                        .padding(paddingSize)
                        .background(backgroundColor)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
            Spacer()
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

import SwiftUI

struct OnboardingOpeningPage: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    AppBackgroundView()
                        .environmentObject(starManager)
                    
                    VStack(spacing: minLength * 0.04) {
                        Spacer()
                        
                        Text("Aligna")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.12))
                            .foregroundColor(themeManager.foregroundColor)
                        
                        Text("FIND YOUR FLOW")
                            .font(.subheadline)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                        
                        Image("openingSymbol") // 请确保这个图标已加入 Assets 中，命名为 openingSymbol
                            .resizable()
                            .scaledToFit()
                            .frame(width: minLength * 0.35)
                        
                        Spacer()
                        
                        // Sign Up 按钮
                        NavigationLink(destination: RegisterPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)) {
                                Text("Sign Up")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .padding(.horizontal, minLength * 0.1)
                            }
                        
                        // Log In 按钮
                        NavigationLink(destination: AccountPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .environmentObject(OnboardingViewModel())) {
                                Text("Log In")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(themeManager.foregroundColor.opacity(0.6), lineWidth: 1)
                                    )
                                    .foregroundColor(themeManager.foregroundColor)
                                    .padding(.horizontal, minLength * 0.1)
                            }
                        
                        Text("Welcome to the Journal of Aligna")
                            .font(.footnote)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.6))
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(.bottom, geometry.size.height * 0.05)
                }
            }
        }
        .onAppear {
            starManager.animateStar = true
            themeManager.updateTheme()
        }
        .navigationBarBackButtonHidden(true)
    }
}

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct RegisterPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToOnboarding = false
    @State private var currentNonce: String? = nil
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    AppBackgroundView()
                        .environmentObject(starManager)
                    
                    VStack {
                        HStack {
                            Button(action: { dismiss() }) {
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
                            
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(themeManager.foregroundColor)
                            
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(themeManager.foregroundColor)
                            
                            Button(action: {
                                registerWithEmailPassword()
                            }) {
                                Text("Register & Send Email")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.foregroundColor)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                            }
                            
                            VStack(spacing: minLength * 0.025) {
                                Text("Or register with")
                                    .font(.footnote)
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.6))
                                
                                HStack(spacing: minLength * 0.08) {
                                    Button(action: {
                                        handleGoogleLogin(viewModel: viewModel, onSuccess: {
                                            navigateToOnboarding = true
                                        }, onError: { message in
                                            alertMessage = message
                                            showAlert = true
                                        })
                                        
                                    }) {
                                        Image("googleIcon")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    
                                    SignInWithAppleButton(
                                        .signUp,
                                        onRequest: { request in
                                            let nonce = randomNonceString()
                                            currentNonce = nonce
                                            request.requestedScopes = [.fullName, .email]
                                            request.nonce = sha256(nonce)
                                        },
                                        onCompletion: { result in
                                            handleAppleLogin(result: result, rawNonce: currentNonce ?? "", onSuccess: {
                                                navigateToOnboarding = true
                                            }, onError: { message in
                                                alertMessage = message
                                                showAlert = true
                                            })
                                        }
                                    )
                                    .frame(width: 140, height: 45)
                                    .signInWithAppleButtonStyle(themeManager.foregroundColor == .black ? .white : .black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.horizontal, geometry.size.width * 0.1)
                        
                        Spacer()
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .navigationDestination(isPresented: $navigateToOnboarding) {
                    OnboardingStep1(viewModel: viewModel)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                }
                .navigationBarBackButtonHidden(true)
            }
        }
    }
    
    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                // 更人性化的错误提示
                if let errCode = AuthErrorCode(rawValue: error._code) {
                    switch errCode.code {
                    case .emailAlreadyInUse:
                        alertMessage = "This email is already in use."
                    case .invalidEmail:
                        alertMessage = "Please enter a valid email address."
                    case .weakPassword:
                        alertMessage = "Password should be at least 6 characters."
                    default:
                        alertMessage = error.localizedDescription
                    }
                } else {
                    alertMessage = error.localizedDescription
                }
                showAlert = true
                return
            }
            
            result?.user.sendEmailVerification { err in
                if let err = err {
                    alertMessage = "Failed to send verification email: \(err.localizedDescription)"
                    showAlert = true
                } else {
                    alertMessage = "✅ Verification email sent. Please check your inbox."
                    showAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        navigateToOnboarding = true
                    }
                }
            }
        }
    }
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
    @State private var isLoading = false
    
    
    var body: some View {
        VStack(spacing: 15) {
            if isLoading {
                ProgressView("Loading, please wait...")
                    .font(.title2)
                    .padding()
            } else {
                Text("Confirm Your Information").font(.title)
                Text("Nickname: \(viewModel.nickname)")
                Text("Gender: \(viewModel.gender)")
                Text("Birthday: \(viewModel.birth_date.formatted(date: .abbreviated, time: .omitted))")
                Text("Time: \(viewModel.birth_time.formatted(date: .omitted, time: .shortened))")
                Text("Place of Birth: \(viewModel.birthPlace)")
                Text("Current Place of Living: \(viewModel.currentPlace)")
                
                Button("Confirm") {
                    isLoading = true
                    uploadUserInfo()
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $navigateToHome) {
            FirstPageView()
                .environmentObject(viewModel)
                .navigationBarBackButtonHidden(true)
        }
        .navigationTitle("完成")
    }
    
    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""
    
    private func uploadUserInfo() {
        print("🚀 uploadUserInfo triggered")
        
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
                        
                        self.isLoading = false
                        
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
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentNonce: String? = nil
    @State private var navigateToHome = false
    
    
    
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
                                    handleGoogleLogin(viewModel: viewModel, onSuccess: {
                                        // 登录 & 写入成功后跳转页面
                                        // e.g., dismiss() 或 navigateToHome = true
                                        DispatchQueue.main.async {
                                            isLoggedIn = true
                                            navigateToHome = true
                                            
                                        }
                                        
                                    }, onError: { message in
                                        alertMessage = message
                                        showAlert = true
                                    })
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
                                        handleAppleLogin(result: result, rawNonce: currentNonce ?? "", onSuccess: {
                                            // 登录完成后的跳转逻辑
                                            DispatchQueue.main.async {
                                                isLoggedIn = true
                                                navigateToHome = true
                                            }
                                        }, onError: { message in
                                            alertMessage = message
                                            showAlert = true
                                        })
                                    }
                                )
                                
                                .frame(width: 140, height: 45)
                                .signInWithAppleButtonStyle(themeManager.foregroundColor == .black ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                
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
            .navigationDestination(isPresented: $navigateToHome) {
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .navigationBarBackButtonHidden(true)
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

func handleGoogleLogin(viewModel: OnboardingViewModel, onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
    print("🔍 准备执行 Google 登录")
    
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase client ID.")
        return
    }
    
    let config = GIDConfiguration(clientID: clientID)
    
    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        onError("No root view controller found.")
        return
    }
    
    GIDSignIn.sharedInstance.configuration = config
    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            onError("Google Sign-In failed: \(error.localizedDescription)")
            return
        }
        
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            onError("Failed to get Google credentials.")
            return
        }
        
        let accessToken = user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                if let errCode = AuthErrorCode(rawValue: (error as NSError).code), errCode == .accountExistsWithDifferentCredential {
                    onError("This email is already registered with a different method. Please use your original login method.")
                    return
                }
                
                onError("Login failed: \(error.localizedDescription)")
                return
            }
            
            print("✅ Google 登录成功")
            onSuccess()
        }
    }
}

func handleAppleLogin(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onSuccess: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    print("🔍 开始处理 Apple 登录结果")
    
    switch result {
    case .success(let authResults):
        print("✅ Apple 授权成功")
        
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple login failed: Cannot retrieve token.")
            return
        }
        
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: tokenString,
            rawNonce: rawNonce
        )
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                if let errCode = AuthErrorCode(rawValue: (error as NSError).code),
                   errCode == .accountExistsWithDifferentCredential {
                    onError("This Apple ID email is already used with another login method. Please use the original method.")
                    return
                }
                
                onError("Apple login failed: \(error.localizedDescription)")
                return
            }
            
            print("✅ Apple 登录成功")
            onSuccess()
        }
        
    case .failure(let error):
        onError("Apple authorization failed: \(error.localizedDescription)")
    }
}



import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfo: Codable {
    var nickname: String
    var birth_date: String
    var birthPlace: String
    var birth_time: String
    var currentPlace: String
}

struct AccountDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var userInfo = UserInfo(nickname: "", birth_date: "", birthPlace: "", birth_time: "", currentPlace: "")
    @State private var isLoading = true
    @State private var errorMessage = ""
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State private var showLogoutAlert = false
    @State private var navigateToOnboarding = false
    
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
                        Text("Welcome, \(userInfo.nickname)")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.07))
                            .foregroundColor(themeManager.foregroundColor)
                            .padding(.top, height * 0.04)
                        
                        VStack(alignment: .leading, spacing: height * 0.04) {
                            Text("Information")
                                .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.06))
                                .foregroundColor(themeManager.foregroundColor)
                            
                            infoRow(title: "Date of Birth", value: userInfo.birth_date, width: width)
                            infoRow(title: "Place of Birth", value: userInfo.birthPlace, width: width)
                            infoRow(title: "Time of Birth", value: userInfo.birth_time, width: width)
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
                        
                        CollapsibleSection(title: "Preference", width: width) {
                            Text("Here you can show user's preferences.")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        CollapsibleSection(title: "Setting", width: width) {
                            Text("Here you can show setting options.")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Text("Log Out")
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, width * 0.1)
                        .padding(.bottom, 20)
                        
                        
                        Spacer()
                    }
                }
            }
            .alert("Are you sure you want to log out?", isPresented: $showLogoutAlert) {
                Button("Log Out", role: .destructive) {
                    handleLogout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                starManager.animateStar = true
                themeManager.updateTheme()
                loadUserInfo()
            }
            .navigationDestination(isPresented: $navigateToOnboarding) {
                OnboardingOpeningPage()
            }
            
        }
    }
    
    private func handleLogout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            navigateToOnboarding = true
            print("✅ 用户已登出")
        } catch {
            print("❌ 登出失败: \(error.localizedDescription)")
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
        db.collection("users")
            .whereField("uid", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        errorMessage = "获取失败: \(error.localizedDescription)"
                        isLoading = false
                        return
                    }
                    
                    guard let document = snapshot?.documents.first else {
                        errorMessage = "未找到该用户的信息"
                        isLoading = false
                        return
                    }
                    
                    let data = document.data()
                    
                    self.userInfo = UserInfo(
                        nickname: data["nickname"] as? String ?? "",
                        birth_date: data["birthDate"] as? String ?? "",
                        birthPlace: data["birthPlace"] as? String ?? "",
                        birth_time: data["birthTime"] as? String ?? "",
                        currentPlace: data["currentPlace"] as? String ?? ""
                    )
                    
                    isLoading = false
                }
            }
    }
}

struct CollapsibleSection<Content: View>: View {
    let title: String
    let content: Content
    let width: CGFloat
    @State private var isExpanded = false
    
    init(title: String, width: CGFloat, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.width = width
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(width: width * 0.8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut, value: isExpanded)
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
    OnboardingFinalStep(viewModel: OnboardingViewModel())
}



