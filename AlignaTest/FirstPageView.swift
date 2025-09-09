import SwiftUI
import Foundation
import MapKit
import CoreLocation

func getAddressFromCoordinate(_ coordinate: CLLocationCoordinate2D,
                              completion: @escaping (String?) -> Void) {
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
        guard error == nil else {
            print("❌ 地址解析失败:", error!.localizedDescription)
            completion(nil)
            return
        }
        if let p = placemarks?.first {
            // pick a friendly name
            let city = p.locality ?? p.administrativeArea ?? p.name
            completion(city)
        } else {
            completion(nil)
        }
    }
}


enum BootPhase {
    case loading
    case infoSplash
    case main
}

func currentZodiacSign(for date: Date = Date()) -> String {
    let cal = Calendar(identifier: .gregorian)
    let (m, d) = (cal.component(.month, from: date), cal.component(.day, from: date))
    switch (m, d) {
    case (3,21...31),(4,1...19):  return "♈︎ Aries"
    case (4,20...30),(5,1...20):  return "♉︎ Taurus"
    case (5,21...31),(6,1...20):  return "♊︎ Gemini"
    case (6,21...30),(7,1...22):  return "♋︎ Cancer"
    case (7,23...31),(8,1...22):  return "♌︎ Leo"
    case (8,23...31),(9,1...22):  return "♍︎ Virgo"
    case (9,23...30),(10,1...22): return "♎︎ Libra"
    case (10,23...31),(11,1...21):return "♏︎ Scorpio"
    case (11,22...30),(12,1...21):return "♐︎ Sagittarius"
    case (12,22...31),(1,1...19): return "♑︎ Capricorn"
    case (1,20...31),(2,1...18):  return "♒︎ Aquarius"
    default:                      return "♓︎ Pisces"
    }
}

/// quick-and-pleasant moon phase label (like your React demo)
func currentMoonPhaseLabel(for date: Date = Date()) -> String {
    // Simple ~29.53 day cycle approximation
    let synodic: Double = 29.53058867
    // Anchor: 2000-01-06 18:14 UTC is a known new moon (approx). Good enough for a splash.
    let anchor = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: .init(secondsFromGMT: 0),
        year: 2000, month: 1, day: 6, hour: 18, minute: 14
    ).date!
    
    let days = date.timeIntervalSince(anchor) / 86400
    let phase = (days - floor(days / synodic) * synodic) // [0, synodic)
    switch phase {
    case 0..<1.84566:  return "🌑 New Moon"
    case 1.84566..<5.53699: return "🌒 Waxing Crescent"
    case 5.53699..<9.22831: return "🌓 First Quarter"
    case 9.22831..<12.91963: return "🌔 Waxing Gibbous"
    case 12.91963..<16.61096: return "🌕 Full Moon"
    case 16.61096..<20.30228: return "🌖 Waning Gibbous"
    case 20.30228..<23.99361: return "🌗 Third Quarter"
    case 23.99361..<27.68493: return "🌘 Waning Crescent"
    default: return "🌑 New Moon"
    }
}

// MARK: - Helpers
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexSanitized.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: opacity)
    }
}

// Subtle text shimmer like your React “brand-title animate-text-shimmer”
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.7), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .blendMode(.screen)
                .mask(content)

            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

// MARK: - LoadingView
struct LoadingView: View {
    var onStartLoading: (() -> Void)? = nil
    
    @State private var loadingMessages = [
        "Aligning with the cosmos",
        "Reading celestial patterns",
        "Gathering stellar insights",
        "Preparing your journey"
    ]
    @State private var msgIndex = 0
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var spinFast = false
    @State private var spinSlow = false
    @State private var pulse = false
    @State private var dotPhase: CGFloat = 0
    @State private var bounce = false
    
    @State private var showWelcome = false
    @State private var currentLocation: String = "Your Current Location"
    @State private var zodiacSign: String = ""
    @State private var moonPhase: String = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                // === Nebula effects ===
                // Blue nebula: top-1/4 left-1/3 w-96 h-96 blur-3xl scale(1.5) rgba(59,130,246,0.1)
                Circle()
                    .fill(Color(.sRGB, red: 59/255, green: 130/255, blue: 246/255, opacity: 0.10))
                    .frame(width: 384, height: 384) // w-96 h-96
                    .scaleEffect(1.5)
                    .blur(radius: 48) // ~ blur-3xl
                    .offset(x: geo.size.width * -0.17, y: geo.size.height * -0.25)

                // Purple nebula: bottom-1/3 right-1/4 w-80 h-80 blur-3xl scale(1.2) rgba(168,85,247,0.1)
                Circle()
                    .fill(Color(.sRGB, red: 168/255, green: 85/255, blue: 247/255, opacity: 0.10))
                    .frame(width: 320, height: 320) // w-80 h-80
                    .scaleEffect(1.2)
                    .blur(radius: 48)
                    .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.18)

                // === Central radial glow: rgba(255,255,255,0.05) at center to transparent ===
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.05), .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height) * 0.5
                )
                .allowsHitTesting(false)

                // === Main content ===
                VStack(spacing: 32) {
                    // Logo + pulse-gentle
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 96, height: 96) // w-24 h-24
                            .shadow(color: .white.opacity(0.35), radius: 24, x: 0, y: 8)
                            .scaleEffect(pulse ? 1.04 : 1.0)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
                            .overlay(
                                Image("logoImage") // ⬅️ put the same asset name you use on iOS
                                    .resizable()
                                    .scaledToFit()
                                    .padding(12) // p-3
                            )
                    }
                    .onAppear {
                        onStartLoading?()
                        pulse = true
                    }

                    // Brand title + thin underline + shimmer
                    VStack(spacing: 8) {
                        Text("Aligna")
                            .font(.custom("PlayfairDisplay-Regular", size: 40)) // ~ text-4xl
                            .foregroundColor(.white)
                            .shimmer()

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.6), .clear],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: 128, height: 1) // w-32 h-0.5
                    }

                    // Spinner (two rings) EXACT behavior
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.20), lineWidth: 2)
                            .frame(width: 64, height: 64)

                        // Fast ring (1s), “border-t-transparent” look via Trim arc
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(spinFast ? 360 : 0))
                            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spinFast)

                        // Slow ring (2s), semi-opaque
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(spinSlow ? 360 : 0))
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: spinSlow)
                    }
                    .onAppear { spinFast = true; spinSlow = true }

                    // Loading text + bouncing dots (three)
                    VStack(spacing: 12) {
                        Text(loadingMessages[msgIndex])
                            .foregroundColor(.white.opacity(0.9))
                            .font(.system(size: 18))
                            .id(msgIndex)
                            .transition(.opacity)
                            
                        HStack(spacing: 6) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 8, height: 8)
                                    .offset(y: bounce ? -6 : 0) // up by 6pt
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.15),   // nice cascade
                                        value: bounce
                                    )
                            }
                        }
                        .padding(.top, 15)
                    }
                    .onAppear { bounce = true }
                }
                .frame(maxWidth: 480) // equivalent to max-w-md container
                .padding(16)
            }
            .onAppear {
                // Rotate messages every 2s
                Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        msgIndex = (msgIndex + 1) % loadingMessages.count
                    }
                }
                // drive dot bounce
                withAnimation {
                    dotPhase = 1
                }
            }
        }
    }

    // mimic three “animate-bounce-dot-*” offsets
    private func dotOffset(for i: Int) -> CGFloat {
        // Stagger using index against an ever-toggling phase
        let up = (Int(dotPhase) + i) % 2 == 0
        return up ? -4 : 0
    }
}

struct WelcomeSplashView: View {
    let location: String
    let zodiac: String
    let moon: String
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var appear = false

    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)
            
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .allowsHitTesting(false)
            
            VStack{
                
            }

            VStack(spacing: 22) {
                // Logo in white circle with glow
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 84, height: 84)
                        .shadow(color: .white.opacity(0.35), radius: 22, x: 0, y: 8)
                    Image("logoImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                }
//                .padding(.top, 24)

                
                // Brand + hairline underline
                VStack(spacing: 6) {
                    Text("Aligna")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.white)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.7), .clear],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: 120, height: 1)
                }

                // Info rows (no card; just clean lines)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("📍").font(.title3)
                        Text(location)
                            .foregroundColor(.white.opacity(0.9))
                            .font(.title3)
                    }
                    Text(zodiac)
                        .foregroundColor(.white.opacity(0.85))
                        .font(.body)
                    Text(moon)
                        .foregroundColor(.white.opacity(0.75))
                        .font(.body)
                }
                .padding(.top, 6)
                .padding(.horizontal, 30)
                .frame(maxWidth: 260, alignment: .leading)

            }
            .multilineTextAlignment(.leading)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)
            .animation(.easeOut(duration: 0.45), value: appear)
        }
        .onAppear { appear = true }
    }

    // MARK: - Row
    private func infoRow(dot color: Color, text: String, sf: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))

            Image(systemName: sf)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Text(text)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 16, weight: .regular))
        }
    }
}




struct FirstPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    
    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
    @State private var selectedDate = Date()
    
    @State private var bootPhase: BootPhase = .loading
    @State private var splashLocation: String = "Your Current Location"
    @State private var splashZodiac: String = ""
    @State private var splashMoon: String = ""
    
    private var mainContent: some View {
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
                                    .environmentObject(viewModel)
                            ) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                    .foregroundColor(themeManager.foregroundColor)
                                    .frame(width: 28, height: 28)
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
                            
                            let columns = [
                                GridItem(.flexible(), alignment: .center),
                                GridItem(.flexible(), alignment: .center)
                            ]
                            
                            
                            LazyVGrid(columns: columns, spacing: geometry.size.height * 0.03) {
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
    
    private func startInitialLoad() {
        // kick off location so we can resolve a nice city name for the splash
        locationManager.requestLocation()

        // Kick off your usual recommendation flow.
        // (It currently runs inside `fetchAndSaveRecommendationIfNeeded()` when main appears.
        // We can trigger it here so the main page shows only after data is ready.)
        // You can call your function directly if it doesn’t rely on being in main.
        fetchAndSaveRecommendationIfNeeded()

        // Wait until recommendations arrive (or timeout), then compute splash info.
        waitUntilRecommendationsReady(timeout: 12) {
            resolveSplashInfoAndAdvance()
        }
    }

    /// Polls viewModel.recommendations until non-empty (or timeout)
    private func waitUntilRecommendationsReady(timeout: TimeInterval = 12, poll: TimeInterval = 0.2, onReady: @escaping () -> Void) {
        let start = Date()
        func check() {
            if !viewModel.recommendations.isEmpty {
                onReady()
                return
            }
            if Date().timeIntervalSince(start) > timeout {
                // Timeout: still move on (you can choose to stay on loading if you prefer)
                onReady()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + poll, execute: check)
        }
        check()
    }

    private func resolveSplashInfoAndAdvance() {
        // Compute zodiac/moon locally (fast)
        splashZodiac = currentZodiacSign()
        splashMoon   = currentMoonPhaseLabel()

        // Resolve a friendly city name if we have coordinates now
        if let coord = locationManager.currentLocation {
            getAddressFromCoordinate(coord) { place in
                splashLocation = place ?? "Your Current Location"
                withAnimation(.easeInOut) { bootPhase = .infoSplash }
            }
        } else {
            splashLocation = "Your Current Location"
            withAnimation(.easeInOut) { bootPhase = .infoSplash }
        }
    }



    var body: some View {
        switch bootPhase {
        case .loading:
            LoadingView(onStartLoading: {
                startInitialLoad()
            })
            .ignoresSafeArea()

        case .infoSplash:
            WelcomeSplashView(location: splashLocation,
                              zodiac: splashZodiac,
                              moon: splashMoon)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .onAppear {
                // Show the splash briefly, then go main
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut) { bootPhase = .main }
                }
            }
            .ignoresSafeArea()

        case .main:
            mainContent // (extract your existing NavigationStack content into a computed var)
        }
    }

    private func fetchAllRecommendationTitles() {
        let db = Firestore.firestore()
        for (rawCategory, rawDoc) in viewModel.recommendations {
            // 1) 类别映射（白名单过滤）
            guard let collection = firebaseCollectionName(for: rawCategory) else {
                print("⚠️ 跳过未知类别：\(rawCategory)")
                continue
            }
            // 2) 文档名清洗与校验
            let documentName = sanitizeDocumentName(rawDoc)
            guard !documentName.isEmpty else {
                print("⚠️ 跳过空文档名（\(rawCategory)）")
                continue
            }
            // 3) Firestore 读取
            db.collection(collection).document(documentName).getDocument { snapshot, error in
                if let error = error {
                    print("❌ 加载 \(rawCategory) 标题失败: \(error)")
                    return
                }
                if let data = snapshot?.data(), let title = data["title"] as? String {
                    DispatchQueue.main.async {
                        self.recommendationTitles[rawCategory] = title
                    }
                } else {
                    print("⚠️ \(rawCategory)/\(documentName) 无 title 字段或文档不存在")
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
                    VStack(spacing: 2) {   // ⬅️ tighter spacing
                        // 图标图像
                        SafeImage(name: documentName, renderingMode: .template, contentMode: .fit)
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: geometry.size.width * 0.18)  // slightly smaller to balance text
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 1.5)
                        
                        // 推荐名称（小字体，紧贴图标）
                        Text(recommendationTitles[title] ?? "")
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.033))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, 0.2) // ⬅️ subtle spacing only
                        
                        // 类别标题（和上面稍微拉开）
                        Text(title)
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.05))
                            .foregroundColor(themeManager.foregroundColor)
                            .padding(.top, 2) // ⬅️ tighter than before
                    }
                }
            } else {
                Button {
                    print("⚠️ 无法进入 '\(title)'，推荐结果尚未加载")
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "questionmark.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.18)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                        
                        Text("Loading")
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.033))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                        
                        Text(title)
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.05))
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
            ActivityDetailView(
                documentName: documentName,
                soundDocumentName: viewModel.recommendations["Sound"] ?? ""
            )
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
                        continue
                    }
                    if key == "uid" || key == "createdAt" { continue }
                    if allowedCategories.contains(key), let str = value as? String {
                        recs[key] = sanitizeDocumentName(str)
                    } else {
                        print("ℹ️ 忽略非推荐字段或未知类别：\(key)")
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
    // ✅ 仅允许的类别白名单
    private let allowedCategories: Set<String> = [
        "Place", "Gemstone", "Color", "Scent",
        "Activity", "Sound", "Career", "Relationship"
    ]

    // ✅ 类别 -> 集合名 映射函数（返回可选，未知类别返回 nil）
    private func firebaseCollectionName(for rawCategory: String) -> String? {
        let category = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        switch category {
        case "Place":        return "places"
        case "Gemstone":     return "gemstones"
        case "Color":        return "colors"
        case "Scent":        return "scents"
        case "Activity":     return "activities"
        case "Sound":        return "sounds"
        case "Career":       return "careers"
        case "Relationship": return "relationships"
        default:
            return nil
        }
    }

    // ✅ 文档名清洗：移除会破坏路径的字符（如 /、\、# 等）
    //   Firestore 文档 ID 不允许包含斜杠；这里最小清洗，保留字母数字下划线与连字符。
    private func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }).trimmingCharacters(in: .whitespacesAndNewlines)
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





// 替换你文件中现有的 OnboardingViewModel
import FirebaseFirestore
import FirebaseAuth
import MapKit

class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var gender: String = ""
    @Published var relationshipStatus: String = ""
    @Published var birth_date: Date = Date()
    @Published var birth_time: Date = Date()
    @Published var birthPlace: String = ""
    @Published var currentPlace: String = ""
    @Published var birthCoordinate: CLLocationCoordinate2D?
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var recommendations: [String: String] = [:]
    @Published var dailyMantra: String = ""
    
    // ✅ 新增：Step3 的五个答案
    @Published var scent_dislike: Set<String> = []     // 多选
    @Published var act_prefer: String = ""             // 单选，可清空
    @Published var color_dislike: Set<String> = []     // 多选
    @Published var allergies: Set<String> = []         // 多选
    @Published var music_dislike: Set<String> = []     // 多选
}




import SwiftUI
// 统一进场动画修饰器：按 index 级联
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Binding var show: Bool
    var baseDelay: Double = 0.08
    
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 16)
            .scaleEffect(show ? 1 : 0.985)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.2)
                    .delay(baseDelay * Double(index)),
                value: show
            )
    }
}

extension View {
    func staggered(_ index: Int, show: Binding<Bool>, baseDelay: Double = 0.08) -> some View {
        self.modifier(StaggeredAppear(index: index, show: show, baseDelay: baseDelay))
    }
}

// MARK: - Aligna 标题（逐字母入场）
struct AlignaHeading: View {
    // 保持你原来的入参不变，兼容现有调用
    let textColor: Color
    @Binding var show: Bool

    // 新增可调参数（有默认值，不会破坏现有调用）
    var text: String = "Aligna"
    var fontSize: CGFloat = 34
    var perLetterDelay: Double = 0.07   // 每个字母的出现间隔
    var duration: Double = 0.26         // 单个字母动画时长
    var letterSpacing: CGFloat = 0      // 需要更“松”的字距，可以传入 > 0

    var body: some View {
        let letters = Array(text)
        HStack(spacing: letterSpacing) {
            ForEach(letters.indices, id: \.self) { i in
                Text(String(letters[i]))
                    .font(Font.custom("PlayfairDisplay-Regular", size: fontSize))
                    .foregroundColor(textColor)
                    .opacity(show ? 1 : 0)
                    .offset(y: show ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration).delay(perLetterDelay * Double(i)),
                        value: show
                    )
            }
        }
        .accessibilityLabel(text)
    }
}


// MARK: - Staggered Letters (逐字母入场)
struct StaggeredLetters: View {
    let text: String
    let font: Font
    let color: Color
    let letterSpacing: CGFloat
    let duration: Double       // 单个字母的动画时长
    let perLetterDelay: Double // 每个字母之间的间隔

    @State private var active = false

    var body: some View {
        HStack(spacing: letterSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, ch in
                Text(String(ch))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration)
                            .delay(perLetterDelay * Double(idx)),
                        value: active
                    )
            }
        }
        .onAppear { active = true }
    }
}




struct OnboardingOpeningPage: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    AppBackgroundView(alwaysNight: true)
                        .environmentObject(starManager)
                    
                    VStack(spacing: minLength * 0.04) {
                        Spacer()
                        
                        Text("Aligna")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.12))
                            .foregroundColor(themeManager.foregroundColor)
                        
                        Text("FIND YOUR FLOW")
                            .font(.subheadline)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                        
                        Image("openingSymbol")
                            .resizable()
                            .scaledToFit()
                            .frame(width: minLength * 0.35)
                        
                        Spacer()
                        
                        // Sign Up
                        NavigationLink(destination: RegisterPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)) {
                                Text("Sign Up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal, minLength * 0.1)
                            }

                        // Log In
                        NavigationLink(destination: AccountPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .environmentObject(OnboardingViewModel())) {
                                Text("Log In")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
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
            themeManager.isNight = true
        }
        .navigationBarBackButtonHidden(true)
    }
}

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import FirebaseFirestore

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
    @State private var navigateToLogin = false
    @State private var currentNonce: String? = nil

    // 🔹 入场动画控制
    @State private var showIntro = false

    // 🔹 焦点控制（只高亮当前字段）
    @FocusState private var registerFocus: RegisterField?
    private enum RegisterField { case email, password }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minL = min(w, h)

                let sectionGap  = h * 0.075
                let fieldGap    = minL * 0.030
                let socialGap   = minL * 0.035

                ZStack {
                    AppBackgroundView(alwaysNight: true)
                        .environmentObject(starManager)

                    VStack(spacing: 0) {
                        // 顶部：返回 + 标题
                        VStack(spacing: minL * 0.02) {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(themeManager.foregroundColor)
                                        .padding(10)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .padding(.leading, w * 0.05)
                                Spacer()
                            }

                            VStack(spacing: 8) {
                                AlignaHeading(
                                    textColor: themeManager.foregroundColor,
                                    show: $showIntro,
                                    fontSize: minL * 0.12,
                                    letterSpacing: minL * 0.005
                                )
                                Text("Create Account")
                                    .font(.custom("PlayfairDisplay-Regular", size: 28))
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.9))
                            }
                            .padding(.top, h * 0.01)
                            .staggered(1, show: $showIntro)
                        }
                        .padding(.top, h * 0.05)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        // 表单
                        VStack(spacing: fieldGap) {

                            // Email 外壳承担入场动画；内核承担焦点高亮
                            Group {
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                    .foregroundColor(themeManager.foregroundColor)
                                    .focused($registerFocus, equals: .email)
                                    .focusGlow(
                                        active: registerFocus == .email,
                                        color: themeManager.foregroundColor,
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
                                    .foregroundColor(themeManager.foregroundColor)
                                    .focused($registerFocus, equals: .password)
                                    .focusGlow(
                                        active: registerFocus == .password,
                                        color: themeManager.foregroundColor,
                                        lineWidth: 2.2,
                                        cornerRadius: 14
                                    )
                                    .submitLabel(.done)
                            }
                            .staggered(3, show: $showIntro)
                            .animation(nil, value: registerFocus)

                            Button(action: { registerWithEmailPassword() }) {
                                Text("Register & Send Email")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.foregroundColor)
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                            }
                            .staggered(4, show: $showIntro)
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: sectionGap)

                        // 第三方登录
                        VStack(spacing: socialGap) {
                            Text("Or register with")
                                .font(.footnote)
                                .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                                .staggered(5, show: $showIntro)

                            HStack(spacing: minL * 0.10) {
                                // Google
                                Button(action: {
                                    handleGoogleFromRegister(
                                        onNewUserGoOnboarding: { navigateToOnboarding = true },
                                        onExistingUserGoLogin: { msg in
                                            alertMessage = msg; showAlert = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                navigateToLogin = true
                                            }
                                        },
                                        onError: { message in alertMessage = message; showAlert = true }
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

                                // Apple
                                SignInWithAppleButton(
                                    .signUp,
                                    onRequest: { request in
                                        let nonce = randomNonceString()
                                        currentNonce = nonce
                                        request.requestedScopes = [.fullName, .email]
                                        request.nonce = sha256(nonce)
                                    },
                                    onCompletion: { result in
                                        handleAppleFromRegister(
                                            result: result,
                                            rawNonce: currentNonce ?? "",
                                            onNewUserGoOnboarding: { navigateToOnboarding = true },
                                            onExistingUserGoLogin: { msg in
                                                alertMessage = msg; showAlert = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    navigateToLogin = true
                                                }
                                            },
                                            onError: { message in
                                                alertMessage = message; showAlert = true
                                            }
                                        )
                                    }
                                )
                                .frame(width: 160, height: 50)
                                .signInWithAppleButtonStyle(themeManager.foregroundColor == .black ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .staggered(7, show: $showIntro)
                            }
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: h * 0.08)
                    }
                    // 保险丝：阻断布局隐式动画
                    .transaction { $0.animation = nil }
                }
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
                    AccountPageView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .environmentObject(viewModel)
                }
                .onAppear {
                    themeManager.isNight = true
                    // 入场动画稍后启动
                    showIntro = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                    // 默认聚焦放在入场动画之后，避免“抢镜”
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        registerFocus = .email
                    }
                }
                .onDisappear { showIntro = false }
                .navigationBarBackButtonHidden(true)
            }
        }
    }

    // MARK: - Email & Password 注册（维持你的原有逻辑）
    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                if let errCode = AuthErrorCode(rawValue: error._code),
                   errCode == .emailAlreadyInUse {
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

import SwiftUI
import MapKit

struct AlignaTopHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
            Text("Aligna")
                .font(Font.custom("PlayfairDisplay-Regular", size: 34))
                .foregroundColor(.white)
        }
    }
}
extension Text {
    func onboardingQuestionStyle() -> some View {
        self.font(.custom("PlayfairDisplay-Regular", size: 17)) // 统一字号
            .foregroundColor(.white) // 统一颜色
            .multilineTextAlignment(.center) // 统一居中
            .frame(maxWidth: .infinity)
    }
}




import SwiftUI
import MapKit

struct OnboardingStep1: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let panelBG = Color.white.opacity(0.08)
    private let stroke   = Color.white.opacity(0.25)

    // 出生地搜索
    @State private var birthSearch = ""
    @State private var birthResults: [PlaceResult] = []
    @State private var didSelectBirth = false

    // 🔹 焦点控制
    @FocusState private var step1Focus: Step1Field?
    private enum Step1Field { case nickname, birth }

    // 若你也想给 Step1 做入场级联动画，可以用 showIntro；这里只保留结构
    @State private var showIntro = true

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(alwaysNight: true)

                ScrollView {
                    VStack(spacing: minLength * 0.045) {

                        // 顶部
                        AlignaTopHeader()

                        Text("Tell us about yourself")
                            .onboardingQuestionStyle()
                            .padding(.top, 6)

                        // 基础信息
                        Group {
                            // Nickname
                            VStack(alignment: .center, spacing: 10) {
                                Text("Your Nickname")
                                    .onboardingQuestionStyle()

                                Group {
                                    TextField("Enter your nickname", text: $viewModel.nickname)
                                        .padding()
                                        .background(panelBG)
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                        .focused($step1Focus, equals: .nickname)
                                        .focusGlow(active: step1Focus == .nickname,
                                                   color: .white,
                                                   lineWidth: 2,
                                                   cornerRadius: 12)
                                }
                                .animation(nil, value: step1Focus)
                            }

                            // Gender
                            VStack(alignment: .center, spacing: 10) {
                                Text("Gender")
                                    .onboardingQuestionStyle()

                                HStack(spacing: 10) {
                                    ForEach(["Male", "Female", "Other"], id: \.self) { gender in
                                        Button {
                                            viewModel.gender = gender
                                        } label: {
                                            Text(gender)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(viewModel.gender == gender ? Color.white : panelBG)
                                                .foregroundColor(viewModel.gender == gender ? .black : .white)
                                                .overlay(RoundedRectangle(cornerRadius: 10)
                                                    .stroke(stroke, lineWidth: 1))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }

                            // Relationship
                            VStack(alignment: .center, spacing: 10) {
                                Text("Status")
                                    .onboardingQuestionStyle()

                                HStack(spacing: 10) {
                                    ForEach(["Single", "In a relationship"], id: \.self) { status in
                                        Button {
                                            viewModel.relationshipStatus = status
                                        } label: {
                                            Text(status)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(viewModel.relationshipStatus == status ? Color.white : panelBG)
                                                .foregroundColor(viewModel.relationshipStatus == status ? .black : .white)
                                                .overlay(RoundedRectangle(cornerRadius: 10)
                                                    .stroke(stroke, lineWidth: 1))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // 出生地
                        VStack(alignment: .center, spacing: 12) {
                            Text("Place of Birth")
                                .onboardingQuestionStyle()

                            Group {
                                TextField("Your Birth Place", text: $birthSearch)
                                    .padding()
                                    .background(panelBG)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .focused($step1Focus, equals: .birth)
                                    .focusGlow(active: step1Focus == .birth,
                                               color: .white,
                                               lineWidth: 2,
                                               cornerRadius: 12)
                                    .onChange(of: birthSearch) { _, newVal in
                                        if !didSelectBirth && !newVal.isEmpty {
                                            performBirthSearch(query: newVal)
                                        }
                                        didSelectBirth = false
                                    }
                            }
                            .animation(nil, value: step1Focus)

                            if !viewModel.birthPlace.isEmpty {
                                Text("✓ Selected: \(viewModel.birthPlace)")
                                    .font(.footnote)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            VStack(spacing: 8) {
                                ForEach(birthResults) { result in
                                    Button {
                                        viewModel.birthPlace = result.name
                                        viewModel.birthCoordinate = result.coordinate
                                        birthSearch = result.name
                                        birthResults = []
                                        didSelectBirth = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.name)
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(panelBG)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Continue
                        NavigationLink(destination: OnboardingStep2(viewModel: viewModel)
                            .environmentObject(themeManager)) {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isFormComplete ? Color.white : Color.white.opacity(0.1))
                                    .foregroundColor(isFormComplete ? .black : .white)
                                    .cornerRadius(16)
                                    .shadow(color: .white.opacity(isFormComplete ? 0.15 : 0),
                                            radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal)
                            .disabled(!isFormComplete)

                        // Back
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .onAppear {
                themeManager.isNight = true
                // 如需默认聚焦：同样延迟到入场动画（若有）之后
                // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { step1Focus = .nickname }
            }
        }
    }

    private var isFormComplete: Bool {
        !viewModel.nickname.isEmpty &&
        !viewModel.gender.isEmpty &&
        !viewModel.relationshipStatus.isEmpty &&
        !viewModel.birthPlace.isEmpty
    }

    private func performBirthSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        MKLocalSearch(request: request).start { response, _ in
            guard let items = response?.mapItems else { return }
            let results = items.compactMap { item in
                PlaceResult(
                    name: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
            DispatchQueue.main.async { self.birthResults = results }
        }
    }
}

// MARK: - OnboardingStep2（顶部与 Step1/Step3 一致，日期/时间用弹出滚轮）
struct OnboardingStep2: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    // 弹窗控制
    @State private var showDatePickerSheet = false
    @State private var showTimePickerSheet = false

    // 临时选择值（用于滚轮，不直接写回 VM）
    @State private var tempBirthDate: Date = Date()
    @State private var tempBirthTime: Date = Date()

    private let panelBG = Color.white.opacity(0.08)
    private let stroke  = Color.white.opacity(0.25)

    // 生日范围（1900 ~ 今天）
    private var dateRange: ClosedRange<Date> {
        var comps = DateComponents()
        comps.year = 1900; comps.month = 1; comps.day = 1
        let calendar = Calendar.current
        let start = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
        let end = Date()
        return start...end
    }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(alwaysNight: true)

                VStack(spacing: minLength * 0.05) {
                    // ✅ 顶部与 Step1/Step3 完全一致
                    AlignaTopHeader()

                    // 说明小字
                    Text("When were you born?")
                        .onboardingQuestionStyle()
                        .padding(.top, 10)

                    // Birthday 卡片（点击后弹出滚轮）
                    VStack(spacing: 15) {
                        Text("Birthday").onboardingQuestionStyle()

                        Button {
                            tempBirthDate = viewModel.birth_date
                            showDatePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_date.formatted(.dateTime.year().month(.wide).day()))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Time of Birth 卡片（点击后弹出滚轮）
                    VStack(spacing: 15) {
                        Text("Time of Your Birth").onboardingQuestionStyle()

                        Button {
                            tempBirthTime = viewModel.birth_time
                            showTimePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_time.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Continue（样式与 Step1/Step3 一致）
                    NavigationLink(
                        destination: OnboardingStep3(viewModel: viewModel)
                    ) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    // Back（样式与 Step1/Step3 一致）
                    Button(action: { dismiss() }) {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
            .onAppear {
                themeManager.isNight = true
                // 默认值兜底，避免首次为空显示异常
                if viewModel.birth_date.timeIntervalSince1970 == 0 {
                    viewModel.birth_date = Date()
                }
                if viewModel.birth_time.timeIntervalSince1970 == 0 {
                    viewModel.birth_time = Date()
                }
            }
            // 日期滚轮弹窗
            .sheet(isPresented: $showDatePickerSheet) {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            viewModel.birth_date = tempBirthDate
                            showDatePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark) // 夜间滚轮可读
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.45), .medium])
                .background(.black.opacity(0.6))
            }
            // 时间滚轮弹窗
            .sheet(isPresented: $showTimePickerSheet) {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: tempBirthTime)
                            var onlyHM = DateComponents()
                            onlyHM.hour = comps.hour
                            onlyHM.minute = comps.minute
                            viewModel.birth_time = Calendar.current.date(from: onlyHM) ?? tempBirthTime
                            showTimePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.35), .medium])
                .background(.black.opacity(0.6))
            }
        }
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

struct OnboardingStep3: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    // 选项文案（对齐效果图）
    private let scentOptions  = ["Floral scents", "Strong perfumes", "Woody scents",
                                 "Citrus scents", "Spicy scents", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green",
                                 "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet",
                                 "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Classical", "Electronic",
                                 "Country", "Jazz", "Other"]

    private var hasAnySelection: Bool {
        !viewModel.scent_dislike.isEmpty ||
        !viewModel.color_dislike.isEmpty ||
        !viewModel.allergies.isEmpty ||
        !viewModel.music_dislike.isEmpty ||
        !viewModel.act_prefer.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)

            ScrollView {
                VStack(spacing: 24) {
                    header

                    // 说明
                    subHeader(
                        title: "A few quick preferences",
                        subtitle: "This helps us personalize your experience"
                    )

                    // Scents
                    sectionTitle("Any scents you dislike?")
                    chips(options: scentOptions,
                          isSelected: { viewModel.scent_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.scent_dislike, $0) })

                    // Activity
                    sectionTitle("Activity preference?")
                    chips(options: actOptions,
                          isSelected: { viewModel.act_prefer == $0 },
                          toggle: { toggleSingle(&viewModel.act_prefer, $0) })

                    // Colors
                    sectionTitle("Any colors you dislike?")
                    chips(options: colorOptions,
                          isSelected: { viewModel.color_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.color_dislike, $0) })

                    // Allergies
                    sectionTitle("Any allergies we should know about?")
                    chips(options: allergyOpts,
                          isSelected: { viewModel.allergies.contains($0) },
                          toggle: { toggleSet(&viewModel.allergies, $0) })

                    // Music
                    sectionTitle("Any music you dislike?")
                    chips(options: musicOptions,
                          isSelected: { viewModel.music_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.music_dislike, $0) })

                    // Continue / Continue without answers
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text(hasAnySelection ? "Continue" : "Continue without answers")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 8)

                    // Back
                    Button {
                        dismiss()
                    } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            // 顶部 Skip
            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                    }
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header（与 Step1/2 保持一致）
    private var header: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }

            Text("Aligna")
                .font(Font.custom("PlayfairDisplay-Regular", size: 34))
                .foregroundColor(.white)
        }
    }

    // 统一副说明的小字样式
    private func subHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).onboardingQuestionStyle()
            Text(subtitle)
                .onboardingQuestionStyle()
                .opacity(0.8)
        }
        .padding(.top, 6)
    }

    // 统一题干标题的小字样式
    private func sectionTitle(_ title: String) -> some View {
        Text(title).onboardingQuestionStyle()
    }

    // MARK: - 固定三列的 Chips（大小一致、间距一致）
    private func chips(options: [String],
                       isSelected: @escaping (String) -> Bool,
                       toggle: @escaping (String) -> Void) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { opt in
                Button {
                    toggle(opt)
                } label: {
                    let selected = isSelected(opt)
                    Text(opt)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity) // 填满单元列宽
                        .frame(height: 44)          // 统一高度
                        .background(selected ? Color.white : Color.white.opacity(0.08))
                        .foregroundColor(selected ? .black : .white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(selected ? 0.0 : 0.25), lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toggle Helpers
    private func toggleSet(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
    private func toggleSingle(_ current: inout String, _ value: String) {
        current = (current == value) ? "" : value
    }
}

// ===============================
// MARK: - FlexibleWrap / FlowLayout（修复版）
// ===============================
struct FlexibleWrap<Content: View>: View {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        // 注意：这里返回的是 FlowLayout{ ... }，不是再次调用 FlexibleWrap 本身
        FlowLayout(spacing: spacing, runSpacing: runSpacing) {
            content()
        }
    }
}

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12

    // ❗️不要写带 @ViewBuilder 的 init，会覆盖系统合成的带内容闭包的初始化
    init(spacing: CGFloat = 12, runSpacing: CGFloat = 12) {
        self.spacing = spacing
        self.runSpacing = runSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews, placing: false)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        _ = layout(proposal: proposal, subviews: subviews, placing: true, in: bounds)
    }

    private func layout(proposal: ProposedViewSize,
                        subviews: Subviews,
                        placing: Bool,
                        in bounds: CGRect = .zero) -> CGSize {
        let maxWidth = proposal.width ?? (placing ? bounds.width : .greatestFiniteMagnitude)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }

            if placing {
                let origin = CGPoint(x: bounds.minX + x, y: bounds.minY + y)
                sv.place(at: origin, proposal: .unspecified)
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
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


import SwiftUI
import CoreLocation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct OnboardingFinalStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // 位置 & 流程
    @StateObject private var locationManager = LocationManager()
    @State private var locationMessage = "Requesting location permission..."
    @State private var didAttemptReverseGeocode = false

    // 上传/跳转
    @State private var isLoading = false
    @State private var navigateToHome = false

    // 入场动画
    @State private var showIntro = false

    var body: some View {
        GeometryReader { geo in
            let minL = min(geo.size.width, geo.size.height)

            ZStack {
                // 夜空背景（与 Step1~3 一致）
                AppBackgroundView(alwaysNight: true)
                    .environmentObject(starManager)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: minL * 0.04) {

                        // 顶部：Logo + “Aligna”（逐字母入场）
                        VStack(spacing: 12) {
                            if let _ = UIImage(named: "alignaSymbol") {
                                Image("alignaSymbol")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: minL * 0.18, height: minL * 0.18)
                                    .staggered(0, show: $showIntro)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: minL * 0.18))
                                    .foregroundColor(.white)
                                    .staggered(0, show: $showIntro)
                            }

                            AlignaHeading(
                                textColor: themeManager.foregroundColor,
                                show: $showIntro,
                                text: "Aligna",
                                fontSize: minL * 0.12,
                                perLetterDelay: 0.06,
                                duration: 0.22,
                                letterSpacing: minL * 0.004
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.top, minL * 0.06)

                        // 小副标题
                        Text("Confirm your information")
                            .font(.custom("PlayfairDisplay-Regular", size: minL * 0.05))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .staggered(1, show: $showIntro)

                        // 信息条目（用 emoji 当图标，参考你给的图）
                        VStack(alignment: .leading, spacing: minL * 0.022) {

                            bulletRow(emoji: "👤",
                                      text: "Nickname: \(viewModel.nickname)")
                                .staggered(2, show: $showIntro)

                            bulletRow(emoji: "⚧️",
                                      text: "Gender: \(viewModel.gender)")
                                .staggered(3, show: $showIntro)

                            bulletRow(emoji: "📅",
                                      text: "Birthday: \(viewModel.birth_date.formatted(.dateTime.year().month().day()))")
                                .staggered(4, show: $showIntro)

                            bulletRow(emoji: "⏰",
                                      text: "Time of Birth: \(viewModel.birth_time.formatted(date: .omitted, time: .shortened))")
                                .staggered(5, show: $showIntro)

                            bulletRow(
                                emoji: "📍",
                                text: viewModel.currentPlace.isEmpty
                                    ? locationMessage
                                    : "Your Current Location: \(viewModel.currentPlace)"
                            )
                            .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)

                        // Loading
                        if isLoading {
                            ProgressView("Loading, please wait...")
                                .foregroundColor(themeManager.foregroundColor)
                                .padding(.top, 6)
                                .staggered(7, show: $showIntro)
                        }

                        // 确认按钮（与 Step1~3 样式一致）
                        Button {
                            guard !isLoading else { return }
                            isLoading = true
                            uploadUserInfo()
                        } label: {
                            Text("Confirm")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.foregroundColor)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.top, 6)
                        .staggered(8, show: $showIntro)

                        // 返回（与 Step1~3 一致）
                        Button {
                            // 交给上级导航返回
                            //（FinalStep 通常从 Step3 进入，直接 pop 即可）
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.bottom, minL * 0.08)
                        .staggered(9, show: $showIntro)
                    }
                }
            }
            .onAppear {
                themeManager.isNight = true
                starManager.animateStar = true

                // 入场动画启动
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }

                // 进页面即发起位置权限与解析
                didAttemptReverseGeocode = false
                locationMessage = "Requesting location permission..."
                locationManager.requestLocation()
            }
            // 监听坐标，做反向地理编码
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                guard !didAttemptReverseGeocode else { return }
                didAttemptReverseGeocode = true
                reverseGeocode(coord) { place in
                    if let place = place {
                        viewModel.currentPlace = place
                        viewModel.currentCoordinate = coord
                        locationMessage = "✓ Current Place detected: \(place)"
                    } else {
                        locationMessage = "Location acquired, resolving address failed."
                    }
                }
            }
            // 监听权限
            .onReceive(locationManager.$locationStatus.compactMap { $0 }) { status in
                switch status {
                case .denied, .restricted:
                    locationMessage = "Location permission denied. Current place will be left blank."
                default:
                    break
                }
            }
            // 完成后跳首页
            .navigationDestination(isPresented: $navigateToHome) {
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    // MARK: - 单行条目（emoji + 文本）
    private func bulletRow(emoji: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.custom("PlayfairDisplay-Regular", size: 17))
                .foregroundColor(themeManager.foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 反向地理编码
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            if let p = placemarks?.first {
                let city = p.locality ?? p.administrativeArea ?? p.name
                completion(city)
            } else {
                completion(nil)
            }
        }
    }

    // ====== 以下保持你原有逻辑：上传用户信息 + FastAPI 请求并写入 daily_recommendation ======
    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""

    private func uploadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法上传")
            isLoading = false
            return
        }

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
            "relationshipStatus": viewModel.relationshipStatus,
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
                print("✅ 用户信息已保存")
                hasCompletedOnboarding = true
            }
        }

        // FastAPI 请求
        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async { isLoading = false }
                return
            }

            guard let data = data,
                  let raw = String(data: data, encoding: .utf8),
                  let cleanedData = raw.data(using: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                DispatchQueue.main.async { isLoading = false }
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantraText = parsed["mantra"] as? String {
                    DispatchQueue.main.async {
                        viewModel.recommendations = recs
                        self.mantra = mantraText
                        self.isLoading = false

                        guard let userId = Auth.auth().currentUser?.uid else { return }
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        let createdAt = df.string(from: Date())

                        var recommendationData: [String: Any] = recs
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = createdAt
                        recommendationData["mantra"] = mantraText

                        let db = Firestore.firestore()
                        db.collection("daily_recommendation").addDocument(data: recommendationData) { error in
                            if let error = error {
                                print("❌ 保存 daily_recommendation 失败：\(error)")
                            } else {
                                print("✅ 推荐结果保存成功")
                            }
                        }

                        navigateToHome = true
                    }
                } else {
                    print("❌ JSON 解包失败或缺少字段")
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
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
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore
import UIKit

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
    @State private var authBusy = false

    // 🔹 入场动画
    @State private var showIntro = false

    // 🔹 焦点控制
    @FocusState private var loginFocus: LoginField?
    private enum LoginField { case email, password }

    private var panelBG: Color { Color.white.opacity(0.10) }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(alwaysNight: true)
                    .environmentObject(starManager)

                VStack {
                    // 顶部返回
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding()
                                .background(panelBG)
                                .clipShape(Circle())
                                .foregroundColor(themeManager.primaryText)
                        }
                        .padding(.leading, geometry.size.width * 0.05)
                        .padding(.top, geometry.size.height * 0.05)
                        Spacer()
                    }
                    .staggered(0, show: $showIntro)

                    Spacer(minLength: geometry.size.height * 0.03)

                    // 标题区
                    VStack(spacing: minLength * 0.02) {
                        AlignaHeading(
                            textColor: themeManager.foregroundColor,
                            show: $showIntro,
                            fontSize: minLength * 0.12,
                            letterSpacing: minLength * 0.005
                        )

                        VStack(spacing: 6) {
                            Text("Welcome Back")
                                .font(.title3)
                                .foregroundColor(themeManager.primaryText)
                            Text("Sign in to continue your journey")
                                .font(.subheadline)
                                .foregroundColor(themeManager.descriptionText)
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
                                .foregroundColor(themeManager.primaryText)
                                .placeholder(when: email.isEmpty) {
                                    Text("Enter your email")
                                        .foregroundColor(themeManager.descriptionText)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .email)
                                .focusGlow(active: loginFocus == .email,
                                           color: themeManager.foregroundColor,
                                           lineWidth: 2,
                                           cornerRadius: 14)
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
                                .foregroundColor(themeManager.primaryText)
                                .placeholder(when: password.isEmpty) {
                                    Text("Enter your password")
                                        .foregroundColor(themeManager.descriptionText)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .password)
                                .focusGlow(active: loginFocus == .password,
                                           color: themeManager.foregroundColor,
                                           lineWidth: 2,
                                           cornerRadius: 14)
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
                                .font(.footnote)
                                .foregroundColor(themeManager.descriptionText)
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
        if let error = error, let code = AuthErrorCode(rawValue: (error as NSError).code) {
            switch code {
            case .wrongPassword:      alertMessage = "Incorrect password. Please try again."
            case .invalidEmail:       alertMessage = "Invalid email address."
            case .userDisabled:       alertMessage = "This account has been disabled."
            case .userNotFound:       alertMessage = "No account found with this email."
            default:                  alertMessage = error.localizedDescription
            }
            showAlert = true
            return
        }
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        navigateToHome = true
    }
}) {
    Text(authBusy ? "Logging in…" : "Log In")
        .frame(maxWidth: .infinity)
        .padding()
        .background(themeManager.foregroundColor)
        .foregroundColor(.black)
        .cornerRadius(14)
}
.disabled(authBusy)
                        .staggered(5, show: $showIntro)

                        // 分隔线
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                            Text("or login with")
                                .font(.footnote)
                                .foregroundColor(themeManager.descriptionText)
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
        },
        onError: { message in
            authBusy = false
            alertMessage = message
            showAlert = true
        }
    )
}) {
                                HStack(spacing: 12) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(themeManager.primaryText)
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
                            guard let raw = currentNonce, !raw.isEmpty else { alertMessage = "Missing nonce. Please try again."; showAlert = true; return }
                            authBusy = true
                            handleAppleLogin(
                                result: result,
                                rawNonce: raw,
                                onSuccessToLogin: { authBusy = false; isLoggedIn = true; navigateToHome = true },
                                onSuccessToOnboarding: { authBusy = false },
                                onError: { message in authBusy = false; alertMessage = message; showAlert = true }
                            )
                                }
                            )
                            .frame(height: 50)
                            .signInWithAppleButtonStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .staggered(8, show: $showIntro)
                        }
                        .padding(.top, 2)

                        // 去注册
                        HStack {
                            Text("Don't have an account?")
                                .font(.footnote)
                                .foregroundColor(themeManager.descriptionText)
                            NavigationLink(destination: RegisterPageView()
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)) {
                                    Text("Sign Up")
                                        .font(.footnote)
                                        .foregroundColor(themeManager.primaryText)
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
            .navigationDestination(isPresented: $navigateToHome) {
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .onAppear {
                themeManager.isNight = true
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                // 登录页不默认聚焦；如需默认聚焦请延迟到入场完成后：
                // DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { loginFocus = .email }
            }
            .onDisappear { showIntro = false }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}


// MARK: - 登录工具函数（可直接替换）
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import FirebaseCore
import UIKit

// 1) 查询用户是否已经在 users 表里存在
func checkIfUserAlreadyRegistered(uid: String, completion: @escaping (Bool) -> Void) {
    let db = Firestore.firestore()
    db.collection("users")
        .whereField("uid", isEqualTo: uid)
        .limit(to: 1)
        .getDocuments { snapshot, error in
            if let error = error {
                print("❌ 查询用户注册状态失败: \(error)")
                completion(false)
                return
            }
            let isRegistered = !(snapshot?.documents.isEmpty ?? true)
            print(isRegistered ? "✅ 用户已注册" : "🆕 用户未注册")
            completion(isRegistered)
        }
}

// 统一设置本地标记（保持你旧代码兼容性）
private func updateLocalFlagsForReturningUser() {
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
    print("🧭 Flags updated: hasCompletedOnboarding=true, isLoggedIn=true")
}

// 2) Google 登录（新版 withPresenting）
func handleGoogleLogin(
    viewModel: OnboardingViewModel,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase client ID.")
        return
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        onError("No root view controller.")
        return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            onError("Google Sign-In failed: \(error.localizedDescription)")
            return
        }
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            onError("Missing Google token.")
            return
        }

        let accessToken = user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Login failed: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("获取 UID 失败")
                return
            }

            // 判断是否老用户 → 决定跳转，并为老用户设置本地 flags
            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        updateLocalFlagsForReturningUser()  // ← 关键：老用户标记完成引导
                        onSuccessToLogin()
                    } else {
                        // 新用户：走 Onboarding，完成后 OnboardingFinalStep 会把 hasCompletedOnboarding 置 true
                        onSuccessToOnboarding()
                    }
                }
            }
        }
    }
}

// 3) Apple 登录
func handleAppleLogin(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    switch result {
    case .success(let authResults):
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple 登录失败，无法获取 token")
            return
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: tokenString,
            rawNonce: rawNonce
        )

        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Apple 登录失败: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("获取 UID 失败")
                return
            }

            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        updateLocalFlagsForReturningUser()  // ← 关键：老用户标记完成引导
                        onSuccessToLogin()
                    } else {
                        onSuccessToOnboarding()
                    }
                }
            }
        }

    case .failure(let error):
        onError("Apple 授权失败: \(error.localizedDescription)")
    }
}

// ===============================
// 注册页专用：Google
// ===============================
func handleGoogleFromRegister(
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (String) -> Void
) {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase client ID.")
        return
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        onError("No root view controller.")
        return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            onError("Google Sign-In failed: \(error.localizedDescription)")
            return
        }
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            onError("Missing Google token.")
            return
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        Auth.auth().signIn(with: credential) { _, error in
            if let error = error {
                onError("Login failed: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("Missing UID after sign in.")
                return
            }
            // ✅ 以 Firestore users 表为准做分流
            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        onExistingUserGoLogin("This Google account is already registered. Redirecting to Sign In…")
                        try? Auth.auth().signOut()
                    } else {
                        onNewUserGoOnboarding()
                    }
                }
            }
        }
    }
}


// ===============================
// 注册页专用：Apple
// ===============================
func handleAppleFromRegister(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (String) -> Void
) {
    switch result {
    case .success(let authResults):
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple 登录失败，无法获取 token")
            return
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: tokenString,
            rawNonce: rawNonce
        )

        Auth.auth().signIn(with: credential) { _, error in
            if let error = error {
                onError("Apple 登录失败: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("Missing UID after sign in.")
                return
            }
            // ✅ 以 Firestore users 表为准做分流
            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        onExistingUserGoLogin("This Apple ID is already registered. Redirecting to Sign In…")
                        try? Auth.auth().signOut()
                    } else {
                        onNewUserGoOnboarding()
                    }
                }
            }
        }

    case .failure(let error):
        onError("Apple 授权失败: \(error.localizedDescription)")
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
                    NavigationLink(destination: OnboardingOpeningPage()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                        ) {
                            Text("Go to Onboarding")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(themeManager.foregroundColor)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
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

/// 安全加载本地 Asset 的图片：
/// - 若找不到对应的图片名，不会崩溃，而是回退到系统占位图标。
struct SafeImage: View {
    let name: String
    let renderingMode: Image.TemplateRenderingMode?
    let contentMode: ContentMode

    init(
        name: String,
        renderingMode: Image.TemplateRenderingMode? = .template,
        contentMode: ContentMode = .fit
    ) {
        self.name = name
        self.renderingMode = renderingMode
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .renderingMode(renderingMode)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
                    .opacity(0.5)
            }
        }
        .accessibilityLabel(Text(name.isEmpty ? "image" : name))
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

// MARK: - Focus Glow (文本框获得焦点时高亮+发光)
struct FocusGlow: ViewModifier {
    var active: Bool
    var color: Color = .white
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            // 边框描边（焦点时加粗）
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(active ? 0.95 : 0.28),
                            lineWidth: active ? lineWidth : 1)
            )
            // 柔和发光（焦点时出现）
            .shadow(color: color.opacity(active ? 0.55 : 0.0), radius: active ? 10 : 0, x: 0, y: 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: active)
    }
}

extension View {
    /// 为可输入控件添加焦点高亮效果
    func focusGlow(active: Bool,
                   color: Color = .white,
                   lineWidth: CGFloat = 2,
                   cornerRadius: CGFloat = 14) -> some View {
        modifier(FocusGlow(active: active, color: color, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}


#Preview {
    OnboardingFinalStep(viewModel: OnboardingViewModel())
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
}
