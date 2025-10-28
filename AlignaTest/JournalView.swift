import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct JournalView: View {
    let date: Date
    
    @State private var text: String = ""
    @State private var journalDocID: String? = nil
    @State private var recommendationDocID: String? = nil
    @State private var isSaving: Bool = false
    @State private var saveSucceeded: Bool = false
    @State private var showResetConfirm = false
    private enum StorageMode { case recommendation(String), standaloneUser }
    @State private var storageMode: StorageMode? = nil
    private let allowStandaloneIfNoRec = true
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: Dates
    private var dateStringForQuery: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    
    var body: some View {
        ZStack {
            BackgroundSky().environmentObject(themeManager)
            
            // Page content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    Text("Daily Check-in")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(themeManager.primaryText)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                    
                    Text("Any thoughts you'd like to note for\nyourself today?")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(themeManager.descriptionText)
                        .lineSpacing(2)
                }
                .padding(.top, 10)
                
                // Text area (single rounded glass card)
                GlassCard {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Tap to write…")
                                .foregroundStyle(themeManager.descriptionText.opacity(0.85))
                                .padding(.top, 14)
                                .padding(.horizontal, 16)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 60)
                            .padding(8)
                            .foregroundColor(themeManager.bodyText)
                            .tint(themeManager.accent)
                            .font(.system(.body, design: .rounded))
                    }
                }
                .environmentObject(themeManager)
                .padding(.horizontal, 24)
                
                // Primary action (disabled until text exists)
                Button {
                    Task { await saveEntryAndClose() }
                } label: {
                    Text("Complete Check-in")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .disabled(text.trimmed().isEmpty || isSaving)
                .buttonStyle(PrimaryGhostButtonStyle(
                    disabled: text.trimmed().isEmpty || isSaving
                ))
                .environmentObject(themeManager)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 12)
            }
            .padding(.top, 24) // move content down from the curved top like the mock
            
            // ---- Custom top overlay controls (Back + Reset) ----
            .overlay(alignment: .topLeading) {
                CustomBackButton(
                    iconSize: 18,
                    paddingSize: 8,
                    backgroundColor: Color.black.opacity(0.30),
                    iconColor: themeManager.foregroundColor,
                    topPadding: 44,
                    horizontalPadding: 24
                )
            }
            .overlay(alignment: .topTrailing) {
                Button("Reset") { showResetConfirm = true }
                    .font(.callout)
                    .foregroundStyle(themeManager.descriptionText)
                    .padding(.top, 44)
                    .padding(.trailing, 24)
                    .background(Color.clear)
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)      // hide default "Back"
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Reset entry?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { text = "" }
        } message: {
            Text("This will clear the current text. It won’t delete anything saved previously.")
        }
        .onAppear { loadEntry() }   
    }
    
    // MARK: Firestore (unchanged)
    private func loadEntry() {
        guard let userId = Auth.auth().currentUser?.uid else { print("❌ No user"); return }
        let ds = dateStringForQuery
        let db = Firestore.firestore()
        
        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let recDoc = snapshot?.documents.first {
                    let recID = recDoc.documentID
                    recommendationDocID = recID
                    storageMode = .recommendation(recID)
                    db.collection("daily_recommendation").document(recID)
                        .collection("journals")
                        .order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { journSnap, journErr in
                            if let journDoc = journSnap?.documents.first {
                                journalDocID = journDoc.documentID
                                text = journDoc.data()["text"] as? String ?? ""
                            }
                        }
                } else if allowStandaloneIfNoRec {
                    storageMode = .standaloneUser
                    db.collection("users").document(userId)
                        .collection("journals").document(ds)
                        .getDocument { snap, _ in
                            text = (snap?.data()?["text"] as? String) ?? ""
                        }
                } else {
                    print("❌ no rec doc for selected day")
                }
            }
    }
    
    @MainActor
    private func saveEntryAndClose() async {
        guard !text.trimmed().isEmpty else { return }
        isSaving = true; defer { isSaving = false }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ds = dateStringForQuery

        // Small helper: return to previous screen after saving
        func goHome() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()   // 👈 pops this screen off the navigation stack
        }

        switch storageMode {
        case .recommendation(let recID):
            let journalsRef = db.collection("daily_recommendation")
                .document(recID)
                .collection("journals")

            if let journalID = journalDocID {
                await withCheckedContinuation { c in
                    journalsRef.document(journalID).updateData([
                        "text": text,
                        "updatedAt": Timestamp()
                    ]) { _ in
                        goHome()  // ✅ Jump straight back
                        c.resume()
                    }
                }
            } else {
                await withCheckedContinuation { c in
                    journalsRef.addDocument(data: [
                        "text": text,
                        "createdAt": Timestamp()
                    ]) { _ in
                        goHome()
                        c.resume()
                    }
                }
            }

        case .standaloneUser, .none:
            let doc = db.collection("users").document(userId)
                .collection("journals").document(ds)
            await withCheckedContinuation { c in
                doc.setData([
                    "text": text,
                    "updatedAt": Timestamp()
                ], merge: true) { _ in
                    goHome()
                    c.resume()
                }
            }
        }
    }
}

// MARK: - Button Style (ghost, disabled like the video)
private struct PrimaryGhostButtonStyle: ButtonStyle {
    var disabled: Bool
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        let baseFill = themeManager.panelFill
        return configuration.label
            .foregroundStyle(disabled
                             ? themeManager.descriptionText.opacity(0.65)
                             : themeManager.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            baseFill.opacity(disabled ? 0.55 : (configuration.isPressed ? 0.52 : 0.42)),
                            baseFill.opacity(disabled ? 0.45 : (configuration.isPressed ? 0.46 : 0.36))
                        ], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: .black.opacity(themeManager.isNight ? 0.35 : 0.12), radius: 12, x: 0, y: 8)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Background / GlassCard (tuned to match video)
private struct BackgroundSky: View {
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        ZStack {
            // deeper indigo night gradient
            LinearGradient(
                colors: themeManager.isNight
                    ? [Color(hex: 0x0b1227), Color(hex: 0x15223a), Color(hex: 0x0b1227)]
                    : [Color(hex: 0xf5efe6), Color(hex: 0xe8e3da), Color(hex: 0xf5efe6)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            LinearGradient(
                gradient: Gradient(colors:
                    themeManager.isNight
                        ? [.clear, Color.purple.opacity(0.10), Color.indigo.opacity(0.18)]
                        : [.clear, Color(hex: "#D4A574").opacity(0.12), Color(hex: "#8F643E").opacity(0.10)]
                ),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            RadialGradient(
                colors: [themeManager.isNight ? .white.opacity(0.05) : .white.opacity(0.25), .clear],
                center: .center, startRadius: 10, endRadius: 420
            ).ignoresSafeArea()

            Nebula(color: themeManager.isNight ? Color.blue.opacity(0.10) : Color(hex: "#8F643E").opacity(0.12),
                   size: 320, x: 0.15, y: 0.28, blur: 90)
            Nebula(color: themeManager.isNight ? Color.purple.opacity(0.10) : Color(hex: "#D4A574").opacity(0.12),
                   size: 280, x: 0.82, y: 0.68, blur: 80)

            StarField(starColor: themeManager.isNight ? .white : Color.black.opacity(0.7))
        }
    }
}

private struct Nebula: View {
    let color: Color; let size: CGFloat; let x: CGFloat; let y: CGFloat; let blur: CGFloat
    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: blur)
                .position(x: geo.size.width * x, y: geo.size.height * y)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct StarField: View {
    var starColor: Color = .white
    @State private var stars: [Star] = (0..<90).map { _ in .random() }
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for star in stars {
                    var s = star
                    s.twinkle(timeline.date)
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.radius, height: s.radius)
                    context.fill(Path(ellipseIn: rect), with: .color(starColor.opacity(s.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
    struct Star {
        var x: CGFloat, y: CGFloat, radius: CGFloat, speed: Double, phase: Double
        var opacity: CGFloat = 0.6
        mutating func twinkle(_ date: Date) {
            let t = date.timeIntervalSinceReferenceDate * speed + phase
            let base = 0.45 + 0.35 * sin(t)
            opacity = CGFloat(max(0.15, min(0.95, base)))
        }
        static func random() -> Star {
            Star(x: .random(in: 0...1), y: .random(in: 0...1), radius: .random(in: 0.6...1.8),
                 speed: .random(in: 0.6...1.6), phase: .random(in: 0...6.28))
        }
    }
}

// MARK: - Helpers
private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 08) & 0xff) / 255,
                  blue: Double((hex >> 00) & 0xff) / 255,
                  opacity: alpha)
    }
}
