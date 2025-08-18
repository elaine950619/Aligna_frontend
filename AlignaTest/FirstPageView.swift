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


#Preview("Welcome Splash") {
    WelcomeSplashView(
        location: "San Francisco",
        zodiac: currentZodiacSign(),
        moon: currentMoonPhaseLabel()
    )
    .environmentObject(StarAnimationManager())
    .environmentObject(ThemeManager())
    .ignoresSafeArea()
    .frame(width: 390, height: 844) // optional
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
//    private func getAddressFromCoordinate(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
//        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//        let geocoder = CLGeocoder()
//        
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            if let placemark = placemarks?.first {
//                let city = placemark.locality ?? placemark.administrativeArea ?? placemark.name
//                completion(city)
//            } else {
//                print("❌ 地址解析失败: \(error?.localizedDescription ?? "未知错误")")
//                completion(nil)
//            }
//        }
//    }
    
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

//#Preview {
//    OnboardingFinalStep(viewModel: OnboardingViewModel())
//}
//
//

