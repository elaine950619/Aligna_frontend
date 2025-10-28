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
    
    let documentName: String
    @State private var item: RecommendationItem?
    @State private var showPlayer = false
    
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
                                .fill(Color.white.opacity(0.10))
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 2))
                                .frame(width: 56, height: 56)
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#E6D7C3"))
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

struct Glow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color = .white
    var radius: CGFloat = 8
    
    func body(content: Content) -> some View {
        Group {
            if colorScheme == .dark {
                content
                    .shadow(color: color.opacity(0.6), radius: radius)
                    .shadow(color: color.opacity(0.4), radius: radius * 2)
            } else {
                content
            }
        }
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
    let text: String
    
    @State private var pulse = false
    @State private var shimmer = false
    
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
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.06), .clear],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 280
                                )
                            )
                            .blur(radius: 10)
                    )
                    .opacity(0.9)
                    
                Text("“")
                    .font(.custom("PlayfairDisplay-Bold", size: 28))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(shimmer ? 5 : 0))
                    .opacity(shimmer ? 0.7 : 0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: shimmer)

                Text("”")
                    .font(.custom("PlayfairDisplay-Bold", size: 28))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(shimmer ? 185 : 180))
                    .opacity(shimmer ? 0.7 : 0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(3), value: shimmer)

                // the quote text
                Text("\(text)")
                    .font(.custom("PlayfairDisplay-Italic", size: 19))
                    .foregroundColor(Color(white: 0.94).opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .shadow(color: Color.white.opacity(0.18), radius: 10)
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

// MARK: - The prettier sheet

struct GemLinkSheet: View {
    let title: String
    let linkURLString: String?
    let stoneURLString: String?
    let themeManager: ThemeManager
    
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // soft halo background
            RadialGradient(
                colors: [themeManager.foregroundColor.opacity(0.18), .clear],
                center: .top, startRadius: 10, endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
                
                GlassCard {
                    VStack(spacing: 14) {
                        // Icon + title
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [themeManager.foregroundColor.opacity(0.25), .clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
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
                        
                        Divider().overlay(.white.opacity(0.25))
                        
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
                                        .fill(themeManager.foregroundColor.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
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
                        .foregroundColor(.secondary)
                    }
                }
                
                Button(role: .cancel) { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.vertical, 6)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 18)
        }
        // iOS 16+
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // iOS 17+: uncomment if available
        // .presentationBackground(.ultraThinMaterial)
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
            AppBackgroundView().environmentObject(starManager)
            
            CustomBackButton(
                iconSize: 18,
                paddingSize: 8,
                backgroundColor: Color.black.opacity(0.3),
                iconColor: themeManager.foregroundColor,
                topPadding: 44,
                horizontalPadding: 24
            )

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
                        .glow(color: themeManager.primaryText, radius: 6)

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
                            .offset(x: 6, y: 6) // tweak to match your video’s corner placement
                    }
                    .sheet(isPresented: $showLinkSheet) {
                        GemLinkSheet(
                            title: item.title,
                            linkURLString: item.link,
                            stoneURLString: item.stone,
                            themeManager: themeManager
                        )
                        .presentationDragIndicator(.hidden)
                        .presentationDetents([.fraction(0.34), .medium])
                        .preferredColorScheme(.dark)
                        .presentationBackground(.ultraThinMaterial)
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

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [themeManager.foregroundColor.opacity(0.18), .clear],
                center: .top, startRadius: 10, endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                GlassCard {
                    VStack(spacing: 14) {
                        // Title row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [themeManager.foregroundColor.opacity(0.25), .clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
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

                        Divider().overlay(.white.opacity(0.25))

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
                                    Image(systemName: "flame.fill") // candle icon substitute
                                    Text("Open Candle")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(themeManager.foregroundColor.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
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
                                } label: { Label("Copy link URL", systemImage: "doc.on.doc") }
                            }
                            if let s = candleURLString {
                                Button {
                                    UIPasteboard.general.string = s
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: { Label("Copy candle URL", systemImage: "doc.on.doc.fill") }
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                }

                Button(role: .cancel) { dismiss() } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.vertical, 6)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 18)
        }
        .presentationDetents([.fraction(0.42), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // If you target iOS 17+, you can also add:
        // .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}



struct ScentDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    let documentName: String
    @State private var item: RecommendationItem?
    @State private var showLinkSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                ScrollView {
                    CustomBackButton(
                        iconSize: 18, paddingSize: 8,
                        backgroundColor: Color.black.opacity(0.3),
                        iconColor: themeManager.foregroundColor,
                        topPadding: 44, horizontalPadding: 24
                    )

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
                                .glow(color: themeManager.primaryText, radius: 6)

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
                                        linkURLString: item.link,        // expects `link` on RecommendationItem
                                        candleURLString: item.candle,    // expects `candle` on RecommendationItem
                                        themeManager: themeManager
                                    )
                                    .presentationDragIndicator(.hidden)
                                    .presentationDetents([.fraction(0.34), .medium])
                                    .preferredColorScheme(.dark)
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
