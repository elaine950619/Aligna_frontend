import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UIKit

struct JournalView: View {
    let date: Date
    
    @State private var text: String = ""
    @State private var journalDocID: String? = nil
    @State private var recommendationDocID: String? = nil
    @State private var isSaving: Bool = false
    @State private var saveSucceeded: Bool = false
    @State private var showResetConfirm = false
    @State private var mood: String? = nil
    @State private var stress: String? = nil
    @State private var sleep: String? = nil
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?
    @State private var showNotesEditor: Bool = false
    private enum StorageMode { case recommendation(String), standaloneUser }
    @State private var storageMode: StorageMode? = nil
    private let allowStandaloneIfNoRec = true
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: Dates
    private var dateStringForQuery: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    
    var body: some View {
        GeometryReader { geometry in
            let keyboardInset = max(0, keyboardHeight - geometry.safeAreaInsets.bottom)

            ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            
            // Page content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Check-in")
                        .font(.custom("Merriweather-Bold", size: 26))
                        .foregroundStyle(themeManager.primaryText)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)

                    Text("Tap what feels true right now.")
                        .multilineTextAlignment(.center)
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundStyle(themeManager.descriptionText)
                }
                .frame(height: 64, alignment: .center)

                VStack(spacing: 10) {
                    compactRow(
                        title: "Mood",
                        options: [("sun.max.fill", "Joy"), ("flame.fill", "Anger"), ("cloud.rain.fill", "Grief"), ("leaf.fill", "Calm")],
                        selection: $mood
                    )

                    compactRow(
                        title: "Stress",
                        options: [("minus.circle", "Low"), ("equal.circle", "Med"), ("plus.circle", "High"), ("bolt.circle", "Peak")],
                        selection: $stress
                    )

                    compactRow(
                        title: "Sleep",
                        options: [("bed.double.fill", "Poor"), ("moon.zzz.fill", "OK"), ("sun.max.fill", "Great"), ("zzz", "Rest")],
                        selection: $sleep
                    )

                    sectionTitle("Notes")
                    sectionCard {
                        Button {
                            showNotesEditor = true
                        } label: {
                            ZStack(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Tap to edit notes")
                                        .foregroundStyle(themeManager.descriptionText.opacity(0.85))
                                        .padding(.top, 1)
                                        .padding(.horizontal, 1)
                                } else {
                                    Text(text)
                                        .foregroundColor(themeManager.descriptionText.opacity(0.85))
                                        .font(.system(.body, design: .rounded))
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)

                let hasSelections = mood != nil || stress != nil || sleep != nil
                let disableActions = (!hasSelections && text.trimmed().isEmpty) || isSaving

                HStack(spacing: 12) {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Text("Reset")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(disableActions)
                    .buttonStyle(SecondaryGhostButtonStyle(
                        disabled: disableActions
                    ))
                    .environmentObject(themeManager)

                    Button {
                        Task { await saveEntryAndClose() }
                    } label: {
                        Text("Submit")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(disableActions)
                    .buttonStyle(PrimaryGhostButtonStyle(
                        disabled: disableActions
                    ))
                    .environmentObject(themeManager)
                }
                .padding(.horizontal, 24)
            }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardInset)
                    .allowsHitTesting(false)
            }
            .frame(minHeight: geometry.size.height - 24, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 24) // move content down from the curved top like the mock
            
            // ---- Custom top overlay controls (Back + Reset) ----
            .overlay(alignment: .topLeading) {
                CustomBackButton(
//                    iconSize: 18,
//                    paddingSize: 8,
//                    backgroundColor: Color.black.opacity(0.30),
//                    iconColor: themeManager.foregroundColor,
//                    topPadding: 44,
//                    horizontalPadding: 24
                )
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)      // hide default "Back"
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay {
            if showResetConfirm {
                AlynnaActionDialog(
                    title: "Reset entry?",
                    message: "This will clear the current text. It won’t delete anything saved previously.",
                    symbol: "arrow.counterclockwise.circle",
                    tone: .destructive,
                    primaryButtonTitle: "Reset",
                    primaryAction: resetCurrentEntry,
                    dismissButtonTitle: "Cancel",
                    onDismiss: { showResetConfirm = false }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showNotesEditor) {
            NotesEditorSheet(initialText: text) { updatedText in
                text = updatedText
            }
            .environmentObject(starManager)
            .environmentObject(themeManager)
        }
        .onAppear {
            loadEntry()
            registerKeyboardNotifications()
        }
        .onDisappear { unregisterKeyboardNotifications() }
        .onChange(of: mood, initial: false) { _, _ in
            saveSelectionSnapshotIfPossible()
        }
        .onChange(of: stress, initial: false) { _, _ in
            saveSelectionSnapshotIfPossible()
        }
        .onChange(of: sleep, initial: false) { _, _ in
            saveSelectionSnapshotIfPossible()
        }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom("Merriweather-Bold", size: 15))
            .foregroundColor(themeManager.primaryText.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.bottom, 3)
    }

    private func registerKeyboardNotifications() {
        guard keyboardShowObserver == nil, keyboardHideObserver == nil else { return }

        keyboardShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = frame.height
            }
        }

        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = 0
            }
        }
    }

    private func unregisterKeyboardNotifications() {
        if let observer = keyboardShowObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardShowObserver = nil
        }
        if let observer = keyboardHideObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardHideObserver = nil
        }
    }

    private func resetCurrentEntry() {
        text = ""
        mood = nil
        stress = nil
        sleep = nil
    }

    private func normalizedSelection(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizeNotesText(_ value: String) -> String {
        let prefixes = [
            "Mood:",
            "Stress:",
            "Sleep:"
        ]
        let lines = value.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !prefixes.contains { trimmed.hasPrefix($0) }
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySelections(from data: [String: Any]) {
        func nonEmptyString(_ key: String) -> String? {
            let raw = data[key] as? String ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        mood = nonEmptyString("mood")
        stress = nonEmptyString("stress")
        sleep = nonEmptyString("sleep")
    }

    private func saveSelectionSnapshotIfPossible() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let payload: [String: Any] = [
            "mood": normalizedSelection(mood) ?? "",
            "stress": normalizedSelection(stress) ?? "",
            "sleep": normalizedSelection(sleep) ?? "",
            "updatedAt": Timestamp()
        ]

        let db = Firestore.firestore()

        switch storageMode {
        case .recommendation(let recID):
            let journalsRef = db.collection("daily_recommendation")
                .document(recID)
                .collection("journals")

            if let journalID = journalDocID {
                journalsRef.document(journalID).setData(payload, merge: true)
            } else {
                journalsRef.addDocument(data: payload.merging([
                    "createdAt": Timestamp()
                ]) { $1 })
            }

        case .standaloneUser, .none:
            let ds = dateStringForQuery
            db.collection("users").document(userId)
                .collection("journals").document(ds)
                .setData(payload, merge: true)
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            content()
                .padding(12)
        }
        .environmentObject(themeManager)
    }

    private func compactRow(
        title: String,
        options: [(String, String)],
        selection: Binding<String?>
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 15))
                .foregroundColor(themeManager.primaryText.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(options, id: \.1) { option in
                    optionButton(icon: option.0, label: option.1, selection: selection)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func optionButton(icon: String, label: String, selection: Binding<String?>) -> some View {
        let isSelected = selection.wrappedValue == label
        return Button {
            selection.wrappedValue = label
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.primaryText)
                Text(label)
                    .font(.custom("Merriweather-Bold", size: 9))
                    .foregroundColor(themeManager.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? themeManager.primaryText.opacity(0.14) : Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(themeManager.primaryText.opacity(0.22), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
                                let data = journDoc.data()
                                text = sanitizeNotesText(data["text"] as? String ?? "")
                                applySelections(from: data)
                            }
                        }
                } else if allowStandaloneIfNoRec {
                    storageMode = .standaloneUser
                    db.collection("users").document(userId)
                        .collection("journals").document(ds)
                        .getDocument { snap, _ in
                            let data = snap?.data() ?? [:]
                            text = sanitizeNotesText(data["text"] as? String ?? "")
                            applySelections(from: data)
                        }
                } else {
                    print("❌ no rec doc for selected day")
                }
            }
    }
    
    @MainActor
    private func saveEntryAndClose() async {
        let sanitizedText = sanitizeNotesText(text)
        let hasSelections = mood != nil || stress != nil || sleep != nil
        guard !sanitizedText.trimmed().isEmpty || hasSelections else { return }
        isSaving = true; defer { isSaving = false }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ds = dateStringForQuery

        let selectionPayload: [String: Any] = [
            "mood": normalizedSelection(mood) ?? "",
            "stress": normalizedSelection(stress) ?? "",
            "sleep": normalizedSelection(sleep) ?? ""
        ]

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
                        "text": sanitizedText,
                        "updatedAt": Timestamp()
                    ].merging(selectionPayload) { $1 }) { _ in
                        Task { @MainActor in
                            goHome()  // ✅ Jump straight back
                        }
                        c.resume()
                    }
                }
            } else {
                await withCheckedContinuation { c in
                    journalsRef.addDocument(data: [
                        "text": sanitizedText,
                        "createdAt": Timestamp()
                    ].merging(selectionPayload) { $1 }) { _ in
                        Task { @MainActor in
                            goHome()
                        }
                        c.resume()
                    }
                }
            }

        case .standaloneUser, .none:
            let doc = db.collection("users").document(userId)
                .collection("journals").document(ds)
            await withCheckedContinuation { c in
                doc.setData([
                    "text": sanitizedText,
                    "updatedAt": Timestamp()
                ].merging(selectionPayload) { $1 }, merge: true) { _ in
                    Task { @MainActor in
                        goHome()
                    }
                    c.resume()
                }
            }
        }
    }
}

private struct NotesEditorSheet: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let initialText: String
    let onSave: (String) -> Void

    @State private var draft: String
    @FocusState private var isEditorFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _draft = State(initialValue: initialText)
    }

    var body: some View {
        ZStack {
            (themeManager.isNight ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.custom("Merriweather-Regular", size: 16))

                    Spacer()

                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .font(.custom("Merriweather-Bold", size: 16))
                }
                .foregroundColor(themeManager.accent)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Text("Notes")
                    .font(.custom("Merriweather-Bold", size: 22))
                    .foregroundColor(themeManager.primaryText)

                TextEditor(text: $draft)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .foregroundColor(themeManager.primaryText.opacity(0.92))
                    .tint(themeManager.accent)
                    .font(.system(.body, design: .rounded))
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(themeManager.panelFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isEditorFocused = true
            }
        }
    }
}

#if DEBUG
private extension JournalView {
    init(previewDate: Date, previewText: String) {
        self.init(date: previewDate)
        _text = State(initialValue: previewText)
    }
}

private struct JournalViewPreviewContainer: View {
    let isNight: Bool

    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager

    init(isNight: Bool) {
        self.isNight = isNight

        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        NavigationStack {
            JournalView(
                previewDate: .now,
                previewText: "Today felt quieter than expected. I want to remember the small progress, not just the unfinished parts."
            )
            .environmentObject(starManager)
            .environmentObject(themeManager)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Journal Day") {
    JournalViewPreviewContainer(isNight: false)
}

#Preview("Journal Night") {
    JournalViewPreviewContainer(isNight: true)
}
#endif

// MARK: - Button Style (ghost, disabled like the video)
private struct PrimaryGhostButtonStyle: ButtonStyle {
    var disabled: Bool
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        let baseFill = themeManager.panelFill
        let accentWash = themeManager.accent.opacity(themeManager.isNight ? 0.22 : 0.18)
        return configuration.label
            .foregroundStyle(disabled
                             ? themeManager.descriptionText.opacity(0.65)
                             : themeManager.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            disabled
                                ? baseFill.opacity(0.7)
                                : accentWash.opacity(configuration.isPressed ? 0.92 : 1.0),
                            disabled
                                ? baseFill.opacity(0.58)
                                : baseFill.opacity(configuration.isPressed ? 0.82 : 0.68)
                        ], startPoint: .top, endPoint: .bottom)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        disabled
                            ? themeManager.panelStrokeHi.opacity(0.7)
                            : themeManager.accent.opacity(themeManager.isNight ? 0.45 : 0.35),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(themeManager.isNight ? 0.35 : 0.12), radius: 12, x: 0, y: 8)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SecondaryGhostButtonStyle: ButtonStyle {
    var disabled: Bool
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        let fillOpacity = disabled ? 0.42 : (configuration.isPressed ? 0.36 : 0.28)

        return configuration.label
            .foregroundStyle(
                disabled
                    ? themeManager.descriptionText.opacity(0.6)
                    : themeManager.descriptionText
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(themeManager.panelFill.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(themeManager.panelStrokeHi.opacity(disabled ? 0.45 : 0.75), lineWidth: 1)
            )
            .shadow(color: .black.opacity(themeManager.isNight ? 0.22 : 0.08), radius: 10, x: 0, y: 6)
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
        SwiftUI.TimelineView(.animation) { timeline in
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
