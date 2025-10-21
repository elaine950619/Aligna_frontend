import SwiftUI
import FirebaseFirestore
import FirebaseAuth

private struct ReflectionCompleteView: View {
    let text: String
    let onEdit: () -> Void
    let onReturnHome: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BackgroundSky().environmentObject(themeManager)

            VStack(spacing: 24) {
                // Success glyph
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 12)

                // Title
                Text("Today’s Reflection Complete")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(themeManager.primaryText)
                    .multilineTextAlignment(.center)

                // Saved text in a glass card
                GlassCard {
                    Text("“\(text)”")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(themeManager.bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .environmentObject(themeManager)
                .padding(.horizontal, 24)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Text("Edit Today’s Reflection")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryGhostButtonStyle(disabled: false))
                    .environmentObject(themeManager)

                    Button {
                        onReturnHome()
                    } label: {
                        Text("Return to Home")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryGhostButtonStyle(disabled: false))
                    .environmentObject(themeManager)
                    .opacity(0.9)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)
            }
            .padding(.top, 24)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        // Optional custom back in the completion page too:
        .overlay(alignment: .topLeading) {
            Button(action: { onEdit() }) {
                CustomBackButton(
                    iconSize: 18,
                    paddingSize: 8,
                    backgroundColor: Color.black.opacity(0.30),
                    iconColor: themeManager.foregroundColor,
                    topPadding: 44,
                    horizontalPadding: 24
                )
            }
        }
    }
}


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
    @State private var showComplete = false
    @State private var savedSnapshot = ""
    
    @Environment(\.dismiss) private var dismiss
    @State private var shouldPopAfterSheet = false
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
        .fullScreenCover(isPresented: $showComplete, onDismiss: {
            if shouldPopAfterSheet {
                shouldPopAfterSheet = false
                dismiss()
                DispatchQueue.main.async { dismiss() } 
            }
        }) {
            ReflectionCompleteView(
                text: savedSnapshot,
                onEdit: { showComplete = false },            // just close the sheet
                onReturnHome: {                              // close sheet, then pop
                    shouldPopAfterSheet = true
                    showComplete = false
                }
            )
            .environmentObject(themeManager)
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

        switch storageMode {
        case .recommendation(let recID):
            let journalsRef = db.collection("daily_recommendation").document(recID).collection("journals")

            if let journalID = journalDocID {
                await withCheckedContinuation { c in
                    journalsRef.document(journalID).updateData([
                        "text": text,
                        "updatedAt": Timestamp()
                    ]) { _ in
                        savedSnapshot = text
                        showComplete = true     // <-- present completion here
                        c.resume()
                    }
                }
            } else {
                await withCheckedContinuation { c in
                    journalsRef.addDocument(data: [
                        "text": text,
                        "createdAt": Timestamp()
                    ]) { _ in
                        savedSnapshot = text
                        showComplete = true     // <-- present completion here
                        c.resume()
                    }
                }
            }

        case .standaloneUser, .none:
            let doc = db.collection("users").document(userId).collection("journals").document(ds)
            await withCheckedContinuation { c in
                doc.setData([
                    "text": text,
                    "updatedAt": Timestamp()
                ], merge: true) { _ in
                    savedSnapshot = text
                    showComplete = true
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

//private struct GlassCard<Content: View>: View {
//    @EnvironmentObject var themeManager: ThemeManager
//    @ViewBuilder var content: Content
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) { content }
//            .padding(14)
//            .background(
//                // slightly more contrast for dark (like the video)
//                LinearGradient(colors: [
//                    Color.white.opacity(0.07),
//                    Color.white.opacity(0.03)
//                ], startPoint: .top, endPoint: .bottom)
//                .blendMode(.plusLighter)
//                .background(themeManager.panelFill.opacity(0.35))
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 22, style: .continuous)
//                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
//            )
//            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
//            .shadow(color: .black.opacity(themeManager.isNight ? 0.45 : 0.12), radius: 18, x: 0, y: 14)
//    }
//}

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
