//
//  DetailViewFiles.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 8/17/25.
//

import SwiftUI
import FirebaseFirestore

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                .clipShape(Circle())
                .foregroundColor(Color(hex: "#E6D7C3"))
        }.buttonStyle(.plain)
    }
}

struct RoundGlyphButton: View {
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundColor(Color.white.opacity(0.8))
        }.buttonStyle(.plain)
    }
}

struct ProgressBar: View {
    let progress: Double
    let fill: LinearGradient
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule()
                .fill(fill)
                .frame(width: max(0, min(1, progress)) * 320, height: 8)
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}

struct VinylRecord: View {
    let isRotating: Bool
    let centerImageName: String
    
    var body: some View {
        ZStack {
            // The vinyl disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.9), .black],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 260, height: 260)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )
            
            // The center label
            Image(centerImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))
        }
        // Rotate the *entire* ZStack
        .rotationEffect(.degrees(isRotating ? 360 : 0))
        .animation(
            isRotating
            ? .linear(duration: 5).repeatForever(autoreverses: false)
            : .default,
            value: isRotating
        )
    }
}

import AVFoundation
import FirebaseStorage

@MainActor
final class SoundPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentSoundKey: String? = nil
    @Published var lastErrorMessage: String? = nil

    // 供 View 里读取 duration / currentTime 等（你现在的代码在用 soundPlayer.player?.duration）
    var player: AVAudioPlayer?

    private var downloadTask: StorageDownloadTask?

    /// 你在 Firebase Storage 里存音频的文件夹：sounds/<documentName>.<ext>
    private let storageFolder = "sounds"
    /// 建议优先用 m4a（体积更小），其次 mp3，最后 wav
    private let preferredExtensions = ["m4a", "mp3", "wav"]

    init() {
        configureAudioSession()
        ensureCacheFolderExists()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default) // 允许锁屏/后台播放
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }
    }

    // MARK: - Public API

    /// 直接调用：soundPlayer.playSound(named: documentName)
    func playSound(named rawKey: String) {
        Task { await playSoundFromFirebase(named: rawKey) }
    }

    /// 可选：如果你想把按钮逻辑变简单，用这个
    func togglePlay(named rawKey: String) {
        if isPlaying, currentSoundKey == rawKey {
            pause()
        } else {
            playSound(named: rawKey)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        downloadTask?.cancel()
        downloadTask = nil

        player?.stop()
        player = nil

        isPlaying = false
        isLoading = false
        currentSoundKey = nil
    }

    // MARK: - Core

    private func playSoundFromFirebase(named rawKey: String) async {
        lastErrorMessage = nil

        // 允许 rawKey 传入 "brown_noise" 或 "brown_noise.mp3"
        let normalized = normalizeKey(rawKey)
        let key = normalized.key
        let exts = normalized.extensions

        // 切换音频时，先停止当前播放 & 取消下载
        if currentSoundKey != rawKey {
            stop()
        }
        currentSoundKey = rawKey

        // 1) 先看看本地缓存有没有（避免每次都走网络）
        if let cached = findCachedFileURL(for: key, extensions: exts) {
            startPlayer(with: cached)
            return
        }

        // 2) 没缓存 -> 从 Firebase Storage 下载到缓存 -> 播放
        isLoading = true
        do {
            let localURL = try await downloadFirstAvailableSoundToCache(for: key, extensions: exts)
            startPlayer(with: localURL)
        } catch {
            isLoading = false
            isPlaying = false
            lastErrorMessage = "Failed to load sound: \(error.localizedDescription)"
            print("❌ Firebase audio download error: \(error)")
        }
    }

    private func startPlayer(with url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            player?.play()

            isLoading = false
            isPlaying = true
        } catch {
            isLoading = false
            isPlaying = false
            lastErrorMessage = "AVAudioPlayer error: \(error.localizedDescription)"
            print("❌ AVAudioPlayer error: \(error)")
        }
    }

    // MARK: - Cache

    private func cacheFolderURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AlignaAudioCache", isDirectory: true)
    }

    private func ensureCacheFolderExists() {
        let dir = cacheFolderURL()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func cachedFileURL(for key: String, ext: String) -> URL {
        cacheFolderURL().appendingPathComponent("\(key).\(ext)")
    }

    private func findCachedFileURL(for key: String, extensions: [String]) -> URL? {
        for ext in extensions {
            let url = cachedFileURL(for: key, ext: ext)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    // MARK: - Firebase Storage download

    /// 依次尝试 sounds/<key>.<ext>，找到第一个存在的就下载并返回本地 URL
    private func downloadFirstAvailableSoundToCache(for key: String, extensions: [String]) async throws -> URL {
        var lastError: Error?

        for ext in extensions {
            let localURL = cachedFileURL(for: key, ext: ext)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }

            do {
                return try await downloadSoundTo(localURL: localURL, key: key, ext: ext)
            } catch {
                lastError = error

                // 如果是“对象不存在”，继续尝试下一个扩展名；否则直接抛出
                if isObjectNotFound(error) {
                    continue
                } else {
                    throw error
                }
            }
        }

        throw lastError ?? NSError(domain: "SoundPlayer", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "No audio file found in Firebase Storage for key: \(key)"
        ])
    }

    private func downloadSoundTo(localURL: URL, key: String, ext: String) async throws -> URL {
        let path = "\(storageFolder)/\(key).\(ext)"
        let ref = Storage.storage().reference(withPath: path)

        // 如果之前下载同一文件残留了空文件，先删掉
        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }

        return try await withCheckedThrowingContinuation { continuation in
            downloadTask = ref.write(toFile: localURL) { url, error in
                self.downloadTask = nil

                if let error = error {
                    // 下载失败时删掉残留文件
                    try? FileManager.default.removeItem(at: localURL)
                    continuation.resume(throwing: error)
                    return
                }

                if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "SoundPlayer", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Firebase download finished but file URL is nil"
                    ]))
                }
            }
        }
    }

    private func isObjectNotFound(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == StorageErrorDomain,
           let code = StorageErrorCode(rawValue: ns.code),
           code == .objectNotFound {
            return true
        }
        return false
    }

    private func normalizeKey(_ rawKey: String) -> (key: String, extensions: [String]) {
        // 允许 "name.ext"（比如 brown_noise.mp3）直接传进来
        let parts = rawKey.split(separator: ".")
        guard parts.count >= 2 else {
            return (rawKey, preferredExtensions)
        }

        let ext = String(parts.last!).lowercased()
        let base = parts.dropLast().joined(separator: ".")

        if ext.isEmpty {
            return (rawKey, preferredExtensions)
        }

        // 把显式扩展名提到最前面（例如传了 mp3，就先找/下 mp3）
        var exts = preferredExtensions
        exts.removeAll { $0.lowercased() == ext }
        exts.insert(ext, at: 0)
        return (base, exts)
    }
}

import SwiftUI
import AVFoundation

struct PlayerPopup: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var soundPlayer: SoundPlayer
    
    let documentName: String
    let dismiss: () -> Void
    
    @State private var isPlaying = false
    @State private var isRotating = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)
            
            // Glassy background for the sheet content
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                // Handle + Title
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                
                Text("Now Playing")
                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                    .foregroundColor(themeManager.primaryText.opacity(0.8))
                
                // Vinyl
                VinylRecord(isRotating: isRotating, centerImageName: documentName)
                    .frame(height: 260)
                
                // Title / subtitle
                VStack(spacing: 4) {
                    Text(documentName.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 20))
                        .foregroundColor(Color(hex:"#E6D7C3"))
                    Text("White Noise • Nature Sounds")
                        .font(.custom("PlayfairDisplay-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Controls
                HStack(spacing: 22) {
                    RoundGlyphButton(system: "shuffle") {}
                    RoundGlyphButton(system: "backward.end.fill") {}
                    PlayPauseButton(isPlaying: isPlaying) { togglePlay() }
                    RoundGlyphButton(system: "forward.end.fill") {}
                    RoundGlyphButton(system: "list.bullet") {}
                }
                .padding(.top, 6)
                
                // Progress + times
                VStack(spacing: 10) {
                    ProgressBar(
                        progress: progress,
                        fill: LinearGradient(
                            colors: [Color.white.opacity(0.85), Color(hex:"#E6D7C3")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 320, height: 8)
                    
                    HStack {
                        Text(timeString(currentTime))
                        Spacer()
                        Text(timeString(duration))
                    }
                    .font(.custom("PlayfairDisplay-Regular", size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 320)
                }
                
                // Close
                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 6)
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
        }
        .onAppear { prepareAndStartIfNeeded() }
        .onDisappear { stopTimer() }
    }
    
    // MARK: - Playback
    private func prepareAndStartIfNeeded() {
        if soundPlayer.player == nil {
            soundPlayer.playSound(named: documentName)
        } else {
            soundPlayer.player?.play()
        }
        isPlaying = true
        isRotating = true
        duration = soundPlayer.player?.duration ?? 0
        startTimer()
    }
    
    private func togglePlay() {
        if isPlaying {
            soundPlayer.player?.pause()
            isPlaying = false
            isRotating = false
            // keep timer to update position if you like, or stop:
            // stopTimer()
        } else {
            if soundPlayer.player == nil {
                soundPlayer.playSound(named: documentName)
            } else {
                soundPlayer.player?.play()
            }
            isPlaying = true
            isRotating = true
            duration = soundPlayer.player?.duration ?? 0
            startTimer()
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let p = soundPlayer.player else { return }
            currentTime = p.currentTime
            duration = p.duration
            progress = duration > 0 ? p.currentTime / duration : 0
            if !p.isPlaying {
                isPlaying = false
                isRotating = false
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct SoundDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var soundPlayer: SoundPlayer
    @Environment(\.colorScheme) private var colorScheme
    
    private var playRingFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
    private var playRingStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.12)
    }
    private var playGlyphColor: Color {
        colorScheme == .dark ? Color(hex: "#E6D7C3") : themeManager.foregroundColor.opacity(0.9)
    }

    
    let documentName: String
    @State private var item: RecommendationItem?
    @State private var showPlayer = false
    
    var body: some View {
        ZStack{
//            AppBackgroundView()
//                .environmentObject(starManager)
            
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
                    
                    // image
                    Image(documentName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(themeManager.foregroundColor)
                    
                    Button {
                        showPlayer = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(playRingFill)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(playRingStroke, lineWidth: 2))
                                .frame(width: 56, height: 56)

                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(playGlyphColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)

                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
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
        .sheet(isPresented: $showPlayer) {
            PlayerPopup(
                documentName: documentName,              // pass through your asset name
                dismiss: { showPlayer = false }          // allow the popup to close itself
            )
            // Nice, modern sheet presentation:
            .presentationDetents([.fraction(0.6), .large]) // iOS 16+
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .navigationBarBackButtonHidden(true)
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
//            AppBackgroundView()
//                .environmentObject(starManager)
             
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
                        .foregroundColor(themeManager.foregroundColor)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
                    VStack(spacing: 24) {
                        HStack(spacing: 40) {
                            ForEach(iconItems[0...2]) { item in
                                VStack(spacing: 8) {
                                    Image(item.imageName)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(themeManager.placeIcon)
                                    Text(item.title)
                                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(themeManager.placeIconText)
                                        .fixedSize(horizontal: true, vertical: true)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 24)
                            }
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

struct DailyAnchorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    
    @State private var pulse = false
    @State private var shimmer = false
    
    private var quoteMarkColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.35)
    }
    private var quoteTextColor: Color {
        colorScheme == .dark ? Color(white: 0.94).opacity(0.9) : Color.black.opacity(0.85)
    }
    private var quoteShadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Top gradient divider
            GradientHairline()
                .frame(height: 1)
                .padding(.horizontal, 8)
                .opacity(0.9)

            // ✦ Daily anchor ✦ label with soft halo
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.foregroundColor.opacity(0.10),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 120
                        )
                    )
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .blur(radius: 18)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)

                Text("✦ Daily anchor ✦")
                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                    .foregroundColor(themeManager.foregroundColor.opacity(0.9))
                    .shadow(color: themeManager.foregroundColor.opacity(0.25), radius: 12, x: 0, y: 0)
                    .shadow(color: themeManager.foregroundColor.opacity(0.12), radius: 24, x: 0, y: 0)
            }
            .frame(height: 20)

            // Quote block
            ZStack {
                // background soft plate
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03),
                                colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.01)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.08), lineWidth: 1)
                    )
                    
                Text("“")
                    .font(.custom("PlayfairDisplay-Bold", size: 28))
                    .foregroundColor(quoteMarkColor)
                    .rotationEffect(.degrees(shimmer ? 5 : 0))
                    .opacity(shimmer ? 0.7 : 0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: shimmer)
                
                Text("”")
                    .font(.custom("PlayfairDisplay-Bold", size: 28))
                    .foregroundColor(quoteMarkColor)
                    .rotationEffect(.degrees(shimmer ? 185 : 180))
                    .opacity(shimmer ? 0.7 : 0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(3), value: shimmer)


                // the quote text
                Text(text)
                    .font(.custom("PlayfairDisplay-Italic", size: 19))
                    .foregroundColor(quoteTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .shadow(color: quoteShadowColor, radius: 10)
            }
            .fixedSize(horizontal: false, vertical: true)

            // Bottom gradient divider
            GradientHairline()
                .frame(height: 1)
                .padding(.horizontal, 8)
                .opacity(0.9)
        }
        .onAppear {
            pulse = true
            shimmer = true
        }
    }
}

// thin gradient line with transparent edges
private struct GradientHairline: View {
    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.white.opacity(0.25),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .compositingGroup()
    }
}

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#E8D3B0"),
                        Color(hex: "#D4A574")
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .foregroundColor(.black.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 8)
            .padding(.horizontal, 2)
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
    }
}

import SwiftUI

struct ClickHint: View {
    @Binding var isVisible: Bool
    var label: String = "Click"

    @State private var pulse = false
    @State private var ripple = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(ripple ? 1.35 : 0.9)
                .opacity(ripple ? 0.0 : 0.9)
                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: ripple)

            HStack(spacing: 6) {
                // Use a cursor symbol if available; otherwise just text is fine
                Image(systemName: "cursorarrow") // “cursorarrow.click” exists on newer OS; this one is safer
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            .scaleEffect(pulse ? 1.05 : 0.95)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        }
        .foregroundStyle(.white)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear { pulse = true; ripple = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Gemstone sheet (light theme, same as Scent)

struct GemLinkSheet: View {
    let title: String
    let linkURLString: String?
    let stoneURLString: String?
    let themeManager: ThemeManager
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        ZStack {
            // Background halo adapts to theme
            RadialGradient(
                colors: [
                    isDark
                    ? Color.black.opacity(0.65)
                    : themeManager.foregroundColor.opacity(0.18),
                    .clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Spacer().frame(height: 6)
                
                GlassCard {
                    VStack(spacing: 14) {
                        // Icon + title
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.foregroundColor.opacity(isDark ? 0.32 : 0.25),
                                                .clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(themeManager.primaryText)
                            }
                            
                            Text(title)
                                .font(.custom("PlayfairDisplay-Regular", size: 22))
                                .foregroundColor(themeManager.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.leading)
                            
                            Spacer(minLength: 0)
                        }
                        
                        Divider()
                            .overlay(
                                (isDark ? Color.white : Color.black)
                                    .opacity(0.20)
                            )
                        
                        // Primary button (Bracelet / Link)
                        if let s = linkURLString, let url = URL(string: s) {
                            Button {
                                haptics()
                                openURL(url)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                    Text("Open Bracelet")
                                }
                            }
                            .buttonStyle(GradientButtonStyle())
                        }
                        
                        // Secondary button (Stone)
                        if let s = stoneURLString, let url = URL(string: s) {
                            Button {
                                haptics()
                                openURL(url)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                    Text("Open Stone")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            themeManager.foregroundColor
                                                .opacity(isDark ? 0.16 : 0.08)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            (isDark ? Color.white : themeManager.foregroundColor)
                                                .opacity(isDark ? 0.24 : 0.20),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .foregroundColor(themeManager.primaryText)
                        }
                        
                        // Utility row (copy links)
                        HStack(spacing: 12) {
                            if let s = linkURLString {
                                Button {
                                    UIPasteboard.general.string = s
                                    haptics()
                                } label: {
                                    Label("Copy bracelet URL", systemImage: "doc.on.doc")
                                }
                            }
                            if let s = stoneURLString {
                                Button {
                                    UIPasteboard.general.string = s
                                    haptics()
                                } label: {
                                    Label("Copy stone URL", systemImage: "doc.on.doc.fill")
                                }
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(isDark ? .white.opacity(0.6) : .secondary)
                    }
                }
                
                // Close in accent for light, softer in dark
                Button(role: .cancel) { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.vertical, 6)
                        .padding(.bottom, 8)
                }
                .foregroundColor(
                    isDark
                    ? themeManager.primaryText.opacity(0.85)
                    : themeManager.accent
                )
            }
            .padding(.horizontal, 18)
        }
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
    
    private func haptics() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}



struct GemstoneDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.openURL) private var openURL

    @State private var showLinkSheet = false
    @State private var item: RecommendationItem?

    // Persisted click counter for the gemstone “click” hint
    @AppStorage("aligna.gem.click.count") private var gemClickCount: Int = 0
    private var showGemClickHint: Bool { gemClickCount < 3 }

    let documentName: String

    var body: some View {
        ZStack {
//            AppBackgroundView().environmentObject(starManager)

            VStack(spacing: 20) {
                Text("Gemstone")
                    .foregroundColor(themeManager.watermark)
                    .font(.custom("PlayfairDisplay-Regular", size: 36))
                    .bold()

                if let item = item {
                    Text(item.title)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .bold()

                    Text(item.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.custom("PlayfairDisplay-Italic", size: 17))
                        .foregroundColor(themeManager.descriptionText)

                    // Gem image with click hint overlay in bottom-right corner
                    ZStack(alignment: .bottomTrailing) {
                        Image(documentName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(themeManager.foregroundColor)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // treat as a "click"
                                gemClickCount = min(gemClickCount + 1, 3) // cap at 3
                                showLinkSheet = true
                            }

                        ClickHint(isVisible: .constant(showGemClickHint), label: "Click")
                            .offset(x: 6, y: 6)
                    }
                    .sheet(isPresented: $showLinkSheet) {
                        GemLinkSheet(
                            title: item.title,
                            linkURLString: item.link,
                            stoneURLString: item.stone,
                            themeManager: themeManager
                        )
                    }

                    if let anchor = item.anchor, !anchor.isEmpty {
                        DailyAnchorView(text: anchor)
                            .environmentObject(themeManager)
                            .padding(.top, 8)
                    }

                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText)
                } else {
                    ProgressView("Loading...").padding(.top, 100)
                }
            }
            .padding()
            .onAppear { fetchItem() }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection("gemstones").document(documentName).getDocument { snapshot, error in
            if let error = error { print("❌ Firebase error: \(error)"); return }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ Doc not found / decode failed")
                }
            } catch { print("❌ Decode failed: \(error)") }
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
//            AppBackgroundView()
//                .environmentObject(starManager)

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
                        .foregroundColor(themeManager.descriptionText)
                    
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


struct ScentLinkSheet: View {
    let title: String
    let linkURLString: String?
    let candleURLString: String?
    let themeManager: ThemeManager

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            // Background halo adapts to theme
            RadialGradient(
                colors: [
                    isDark
                    ? Color.black.opacity(0.65)
                    : themeManager.foregroundColor.opacity(0.18),
                    .clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // only system drag indicator
                Spacer().frame(height: 6)

                GlassCard {
                    VStack(spacing: 14) {
                        // Title row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.foregroundColor.opacity(isDark ? 0.32 : 0.25),
                                                .clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)

                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(themeManager.primaryText)
                            }

                            Text(title)
                                .font(.custom("PlayfairDisplay-Regular", size: 22))
                                .foregroundColor(themeManager.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }

                        Divider()
                            .overlay(
                                (isDark ? Color.white : Color.black)
                                    .opacity(0.20)
                            )

                        // Primary button: Link
                        if let s = linkURLString, let url = URL(string: s) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                openURL(url)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                    Text("Open Link")
                                }
                            }
                            .buttonStyle(GradientButtonStyle())
                        }

                        // Secondary button: Candle
                        if let s = candleURLString, let url = URL(string: s) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                openURL(url)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                    Text("Open Candle")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            themeManager.foregroundColor
                                                .opacity(isDark ? 0.16 : 0.08)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            (isDark ? Color.white : themeManager.foregroundColor)
                                                .opacity(isDark ? 0.24 : 0.20),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .foregroundColor(themeManager.primaryText)
                        }

                        // Utility row
                        HStack(spacing: 12) {
                            if let s = linkURLString {
                                Button {
                                    UIPasteboard.general.string = s
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label("Copy link URL", systemImage: "doc.on.doc")
                                }
                            }
                            if let s = candleURLString {
                                Button {
                                    UIPasteboard.general.string = s
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label("Copy candle URL", systemImage: "doc.on.doc.fill")
                                }
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(isDark ? .white.opacity(0.6) : .secondary)
                    }
                }

                // Close: warm accent in light, softer primary text in dark
                Button(role: .cancel) { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.vertical, 6)
                        .padding(.bottom, 8)
                }
                .foregroundColor(
                    isDark
                    ? themeManager.primaryText.opacity(0.85)
                    : themeManager.accent
                )
            }
            .padding(.horizontal, 18)
        }
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // no preferredColorScheme → follow app/system
    }
}






struct ScentDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    let documentName: String
    @State private var item: RecommendationItem?
    @State private var showLinkSheet = false
//    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
//            AppBackgroundView()
//                .environmentObject(starManager)

            ScrollView {

                VStack(spacing: 20) {
                    Text("Scent")
                        .foregroundColor(themeManager.watermark)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .bold()

                    if let item = item {
                        Text(item.title)
                            .multilineTextAlignment(.center)
                            .font(.custom("PlayfairDisplay-Regular", size: 36))
                            .foregroundColor(themeManager.primaryText)
                            .bold()

                        Text(item.description)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .font(.custom("PlayfairDisplay-Italic", size: 17))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(themeManager.descriptionText)

                        Image(documentName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(themeManager.foregroundColor)
                            .onTapGesture { showLinkSheet = true }
                            .sheet(isPresented: $showLinkSheet) {
                                ScentLinkSheet(
                                    title: item.title,
                                    linkURLString: item.link,
                                    candleURLString: item.candle,
                                    themeManager: themeManager
                                )
                                .presentationDragIndicator(.visible)
                                .presentationDetents([.medium, .large])   // more height → no cropping
                                .presentationCornerRadius(28)
                            }

                        Text(item.explanation)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom)
                            .italic()
                            .font(.custom("PlayfairDisplay-Regular", size: 14))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(themeManager.descriptionText)

                        if let about = item.about, !about.isEmpty {
                            VStack(alignment: .center, spacing: 10) {
                                Text("About the Scent")
                                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                                    .foregroundColor(themeManager.foregroundColor)
                                    .bold()
                                    .multilineTextAlignment(.center)

                                Text(about)
                                    .font(.custom("PlayfairDisplay-Italic", size: 15))
                                    .foregroundColor(themeManager.foregroundColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                        }

                        if let notice = item.notice, !notice.isEmpty {
                            VStack(alignment: .center, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("Usage Note")
                                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                                        .foregroundColor(themeManager.accent)
                                        .bold()
                                        .multilineTextAlignment(.center)
                                }
                                Text(notice)
                                    .font(.custom("PlayfairDisplay-Regular", size: 12))
                                    .foregroundColor(themeManager.foregroundColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(14)
                            .background(Color.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.accent.opacity(0.22), lineWidth: 1)
                            )
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        }
                    } else {
                        ProgressView("Loading...")
                            .padding(.top, 100)
                    }
                }
                .padding()
                .onAppear { fetchItem() }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // If you don't already have this:
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
    @EnvironmentObject var soundPlayer: SoundPlayer
    
    let documentName: String
    let soundDocumentName: String
    @State private var item: RecommendationItem?
    
    var body: some View {
        ZStack{
//            AppBackgroundView()
//                .environmentObject(starManager)
            
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
                        .foregroundColor(themeManager.foregroundColor)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
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
//            AppBackgroundView()
//                .environmentObject(starManager)
            
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
                        .foregroundColor(themeManager.descriptionText)
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
//            AppBackgroundView()
//                .environmentObject(starManager)

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
                        .foregroundColor(themeManager.foregroundColor)
                    
                    // Explanation
                    Text(item.explanation)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .italic()
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(themeManager.descriptionText)
                    
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
