import SwiftUI
import AVFAudio
import CoreLocation
import Photos

struct SettingPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var notificationsEnabled = true
    @StateObject private var locationManager = CLLocationManagerDelegateWrapper()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)

            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(themeManager.foregroundColor)
                            .padding()
                    }
                    Spacer()
                }

                Text("Settings")
                    .font(.custom("PlayfairDisplay-Regular", size: 40))
                    .foregroundColor(themeManager.foregroundColor)

                Form {
                    Section(header:
                        Text("Permissions")
                            .font(.custom("PlayfairDisplay-Regular", size: 18).weight(.bold))
                            .foregroundColor(themeManager.foregroundColor)
                    ) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            permissionCard(title: "Location", description: "For place recommendations", systemImage: "location.fill", action: requestLocationPermission)
                            permissionCard(title: "Camera", description: "For visual connection", systemImage: "camera.fill", action: requestCameraPermission)
                            permissionCard(title: "Microphone", description: "For sound detection", systemImage: "mic.fill", action: requestMicrophonePermission)
                            permissionCard(title: "Notifications", description: "For gentle reminders", systemImage: "bell.fill", isToggle: true, isOn: $notificationsEnabled)
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.custom("Intel-Regular", size: 16))
            }
            .padding(.horizontal)
        }
        .onAppear {
            starManager.animateStar = true
            themeManager.updateTheme()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func permissionCard(
        title: String,
        description: String,
        systemImage: String,
        isToggle: Bool = false,
        isOn: Binding<Bool>? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        @GestureState var isPressed = false

        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                state = true
            }

        Group {
            if isToggle, let binding = isOn {
                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                    Toggle(isOn: binding) {
                        VStack(spacing: 4) {
                            Text(title)
                                .font(.custom("Intel-Regular", size: 16).weight(.bold))
                            Text(description)
                                .font(.custom("Intel-Regular", size: 13))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            } else {
                Button(action: {
                    action?()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.system(size: 24))
                        Text(title)
                            .font(.custom("Intel-Regular", size: 16).weight(.bold))
                        Text(description)
                            .font(.custom("Intel-Regular", size: 13))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .foregroundColor(.black)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(hex: "#E6D9BD")) // ✅ 固定颜色
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .shadow(color: isPressed ? .black.opacity(0.3) : .clear, radius: 6, x: 0, y: 4)
        .gesture(pressGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPressed)
        .buttonStyle(PlainButtonStyle())
    }

    func requestLocationPermission() {
        locationManager.requestPermission()
    }

    func requestMicrophonePermission() {
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission { granted in
                print("Microphone permission granted: \(granted)")
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print("Microphone permission granted: \(granted)")
            }
        }
    }

    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("Camera permission granted: \(granted)")
        }
    }
}

class CLLocationManagerDelegateWrapper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    func requestPermission() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }
}

#Preview {
    SettingPageView()
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
}
