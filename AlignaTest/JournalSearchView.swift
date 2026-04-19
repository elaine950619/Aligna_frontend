import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Data model

struct JournalSearchEntry: Identifiable {
    let id: String          // Firestore doc ID
    let date: Date
    let dateKey: String     // "yyyy-MM-dd"
    let text: String
    let mood: String?
    let stress: String?
    let sleep: String?
}

// MARK: - ViewModel

@MainActor
final class JournalSearchViewModel: ObservableObject {
    @Published var entries: [JournalSearchEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var didLoad = false

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        load()
    }

    private func load() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        // Fetch all daily_recommendation docs for this user
        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .getDocuments { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                let recDocs = snap?.documents ?? []
                guard !recDocs.isEmpty else {
                    self.isLoading = false
                    return
                }

                var collected: [JournalSearchEntry] = []
                let group = DispatchGroup()

                for recDoc in recDocs {
                    group.enter()
                    let dateKey: String
                    if let s = recDoc.data()["createdAt"] as? String {
                        dateKey = s
                    } else if let ts = recDoc.data()["createdAt"] as? Timestamp {
                        dateKey = df.string(from: ts.dateValue())
                    } else {
                        group.leave()
                        continue
                    }

                    db.collection("daily_recommendation")
                        .document(recDoc.documentID)
                        .collection("journals")
                        .order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { jSnap, _ in
                            defer { group.leave() }
                            guard let jDoc = jSnap?.documents.first else { return }
                            let data = jDoc.data()
                            let rawText = data["text"] as? String ?? ""
                            let text = Self.sanitize(rawText)
                            guard !text.isEmpty
                                    || data["mood"] as? String != nil
                                    || data["stress"] as? String != nil
                                    || data["sleep"] as? String != nil else { return }

                            let date = df.date(from: dateKey) ?? Date.distantPast
                            let entry = JournalSearchEntry(
                                id: jDoc.documentID,
                                date: date,
                                dateKey: dateKey,
                                text: text,
                                mood: (data["mood"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                                stress: (data["stress"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                                sleep: (data["sleep"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                            )
                            collected.append(entry)
                        }
                }

                group.notify(queue: .main) { [weak self] in
                    guard let self else { return }
                    self.entries = collected.sorted { $0.date > $1.date }
                    self.isLoading = false
                }
            }
    }

    private static func sanitize(_ value: String) -> String {
        let prefixes = ["Mood:", "Stress:", "Sleep:"]
        return value
            .components(separatedBy: .newlines)
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !prefixes.contains { t.hasPrefix($0) }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - View

struct JournalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @StateObject private var vm = JournalSearchViewModel()

    @State private var query = ""
    @State private var moodFilter: String? = nil
    @State private var stressFilter: String? = nil
    @State private var sleepFilter: String? = nil

    // Navigate to a date in timeline
    var onSelectDate: ((Date) -> Void)?

    private let moodOptions   = ["Joy", "Anger", "Grief", "Calm"]
    private let stressOptions = ["Low", "Med", "High", "Peak"]
    private let sleepOptions  = ["Poor", "OK", "Great", "Rest"]

    private var filtered: [JournalSearchEntry] {
        vm.entries.filter { e in
            let textMatch = query.isEmpty || e.text.localizedCaseInsensitiveContains(query)
            let moodMatch = moodFilter == nil || e.mood == moodFilter
            let stressMatch = stressFilter == nil || e.stress == stressFilter
            let sleepMatch = sleepFilter == nil || e.sleep == sleepFilter
            return textMatch && moodMatch && stressMatch && sleepMatch
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    Text("journal.search.title")
                        .font(.custom("Merriweather-Black", size: 20))
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                    // balance the back button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)

                // ── Search field ──
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.descriptionText.opacity(0.5))
                    TextField(String(localized: "journal.search.placeholder"), text: $query)
                        .font(.custom("Merriweather-Regular", size: 15))
                        .foregroundColor(themeManager.primaryText)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeManager.descriptionText.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeManager.panelFill.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(themeManager.panelStrokeHi.opacity(0.25), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // ── Filter chips ──
                VStack(spacing: 8) {
                    filterRow(label: "Mood",   options: moodOptions,   selected: $moodFilter)
                    filterRow(label: "Stress", options: stressOptions, selected: $stressFilter)
                    filterRow(label: "Sleep",  options: sleepOptions,  selected: $sleepFilter)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // ── Divider ──
                Rectangle()
                    .fill(themeManager.descriptionText.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // ── Results ──
                if vm.isLoading {
                    Spacer()
                    Text("journal.search.loading")
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    Text("journal.search.no_results")
                        .font(.custom("Merriweather-Regular", size: 14))
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { entry in
                                entryCard(entry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
        .onAppear { vm.loadIfNeeded() }
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    // MARK: - Filter row

    @ViewBuilder
    private func filterRow(label: String, options: [String], selected: Binding<String?>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Text(label)
                    .font(.custom("Merriweather-Regular", size: 11))
                    .tracking(0.6)
                    .foregroundColor(themeManager.descriptionText.opacity(0.5))
                    .frame(width: 38, alignment: .leading)

                // "All" chip
                chip(title: String(localized: "journal.search.all"),
                     active: selected.wrappedValue == nil) {
                    selected.wrappedValue = nil
                }

                ForEach(options, id: \.self) { opt in
                    chip(title: opt, active: selected.wrappedValue == opt) {
                        selected.wrappedValue = (selected.wrappedValue == opt) ? nil : opt
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Merriweather-Regular", size: 12))
                .foregroundColor(active ? themeManager.buttonForegroundOnPrimary : themeManager.descriptionText.opacity(0.70))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(active ? themeManager.accent : themeManager.panelFill.opacity(0.55))
                )
                .overlay(
                    Capsule()
                        .stroke(active ? Color.clear : themeManager.panelStrokeHi.opacity(0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry card

    @ViewBuilder
    private func entryCard(_ entry: JournalSearchEntry) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onSelectDate?(entry.date)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Date + mood/stress/sleep chips
                HStack(spacing: 6) {
                    Text(DateFormatter.appLong.string(from: entry.date))
                        .font(.custom("Merriweather-Regular", size: 11))
                        .tracking(0.4)
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                    Spacer()
                    if let m = entry.mood   { miniChip(m) }
                    if let s = entry.stress { miniChip(s) }
                    if let sl = entry.sleep { miniChip(sl) }
                }

                // Note preview (2 lines)
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.custom("Merriweather-Regular", size: 13))
                        .lineSpacing(3)
                        .foregroundColor(themeManager.primaryText.opacity(0.80))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(themeManager.panelFill.opacity(themeManager.isNight ? 0.30 : 0.26))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.panelStrokeHi.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func miniChip(_ label: String) -> some View {
        Text(label)
            .font(.custom("Merriweather-Regular", size: 10))
            .foregroundColor(themeManager.descriptionText.opacity(0.65))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(themeManager.panelFill.opacity(0.50))
                    .overlay(Capsule().stroke(themeManager.panelStrokeHi.opacity(0.22), lineWidth: 1))
            )
    }
}
