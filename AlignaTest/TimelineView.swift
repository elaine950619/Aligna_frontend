//
//  TimelineView.swift
//
//
//  Created by Elaine Hsieh on 6/29/25.
//

import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore


struct NoDataMessage: View {
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeManager.accent)

            Text("No data available for this day")
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.primaryText)

            Text(DateFormatter.appLong.string(from: date))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(themeManager.isNight ? 0.04 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

extension DateFormatter {
    static let appLong: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
}

private struct TimelineHeader: View {
    var title: String = "Timeline"
    var iconSize: CGFloat = 26
    var paddingSize: CGFloat = 10
    var backgroundColor: Color = Color.black.opacity(0.3)
    var iconColor: Color = .white
    var topPadding: CGFloat = 0
    var horizontalPadding: CGFloat = 0
    var onBack: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geo in
            // use safe-area top for exact placement under the notch
            let top = geo.safeAreaInsets.top
//            var extraTop: CGFloat = 10

            ZStack {
                
                // back button (leading)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
//                            .padding(paddingSize)
    //                        .background(backgroundColor)
                            .clipShape(Circle())
                            
                    }
                    Spacer()
                }
                .padding(.top, topPadding)
                .padding(.horizontal, horizontalPadding)
                Spacer()
                
                
//                Spacer()
                // centered title
                VStack(spacing: 12) {
                    Text(title)
                        .font(TimelineType.title34GloockBlack())
                        .lineSpacing(TimelineType.title34LineSpacing)
                        .foregroundColor(themeManager.primaryText)
                        .kerning(0.5)


                }
            }
//            .padding(.top, max(top, 12))
            .padding(.horizontal, 20)
            .frame(height: 56 + max(top, 12), alignment: .bottom)   // slightly shorter than 64
            .background(
              // publish the total height to the parent via preference
              Color.clear.preference(key: HeaderHeightKey.self,
                                     value: 56 + max(top, 12))
            )
        }
        .frame(height: 96, alignment: .bottom)
        .padding(.top, 12)                 // geometry reader needs a base height
    }
}



extension DateFormatter {
    static let appDayKey: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}



private struct HeaderHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}


struct SuggestionRow: View {
    let item: SuggestionItem
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme


    // use mapped asset; fallback to computed
    private var iconName: String {
        viewModel.recommendations[item.category] ?? item.assetName
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Give the icon its own vertical lane so it visually spans title + subtitle.
            Group {
                if !iconName.isEmpty, UIImage(named: iconName) != nil {
                    Image(iconName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(themeManager.accent)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(themeManager.accent)
                }
            }
            .frame(width: 32, height: 46, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.title)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(item.category)
                        .font(AlynnaTypography.font(.caption1))
                        .tracking(0.7)
                        .foregroundColor(themeManager.descriptionText.opacity(0.9))
                }

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText)
                        .lineLimit(1)
                }
            }
        }
        // Card container to match the React “soft panel”
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.06)   // dark mode → light capsule
                    : Color.black.opacity(0.06)   // light mode → dark capsule
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
    }
}

private struct TimelineSuggestionDetailSheet: View {
    let item: SuggestionItem

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var viewModel: OnboardingViewModel

    private var iconName: String {
        viewModel.recommendations[item.category] ?? item.assetName
    }

    private var overviewText: String {
        let text = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "No overview available." : text
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    dialogSymbol

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(AlynnaTypography.font(.title3))
                            .foregroundColor(themeManager.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                detailBodyCard(bodyText: overviewText)

                Spacer(minLength: 0)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(item.category)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.descriptionText)
                            .frame(width: 30, height: 30)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var dialogSymbol: some View {
        Group {
            if !iconName.isEmpty, UIImage(named: iconName) != nil {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(themeManager.accent)
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(themeManager.accent)
            }
        }
        .frame(width: 76, height: 76)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailBodyCard(bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(bodyText)
                .font(AlynnaTypography.font(.body))
                .foregroundColor(themeManager.descriptionText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}



struct PlaceholderRow: View {
    let category: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category)
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // empty capsule
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 60)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

struct TimelineView: View {
    private let allCategories = [
        "Place","Color","Gemstone","Scent",
        "Activity","Sound","Career","Relationship"
    ]
    
    @State private var selectedDate = Date()
    @State private var validDayKeys: Set<String> = []
    @StateObject private var dailyVM: DailyViewModel
    @State private var journalText: String = ""
    @State private var isLoadingJournal: Bool = false
    @State private var secondaryLoadTask: Task<Void, Never>? = nil
    @State private var selectedSuggestion: SuggestionItem? = nil

    
    private let enableLoading: Bool

    private func loadTimelineContent(for date: Date) {
        if enableLoading {
            dailyVM.load(for: date)
        }

        secondaryLoadTask?.cancel()
        isLoadingJournal = true
        journalText = ""

        secondaryLoadTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                loadJournal(for: date)
                reasoningStore.load(for: date)
            }
        }
    }
    
    private func loadJournal(for date: Date) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ds = DateFormatter.appDayKey.string(from: date)
        let db = Firestore.firestore()

        isLoadingJournal = true
        journalText = ""

        // 1) Try under daily_recommendation (same logic as JournalView)
        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snap, _ in
                if let recDoc = snap?.documents.first {
                    db.collection("daily_recommendation")
                        .document(recDoc.documentID)
                        .collection("journals")
                        .order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { jSnap, _ in
                            DispatchQueue.main.async {
                                isLoadingJournal = false
                                let raw = jSnap?.documents.first?.data()["text"] as? String ?? ""
                                journalText = sanitizeNotesText(raw)
                            }
                        }
                } else {
                    // 2) fallback: users/{uid}/journals/{yyyy-MM-dd}
                    db.collection("users").document(uid)
                        .collection("journals").document(ds)
                        .getDocument { doc, _ in
                            DispatchQueue.main.async {
                                isLoadingJournal = false
                                let raw = (doc?.data()?["text"] as? String) ?? ""
                                journalText = sanitizeNotesText(raw)
                            }
                        }
                }
            }
    }

    private func isDateSelectable(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.startOfDay(for: date)
        if day > today { return false }
        let key = DateFormatter.appDayKey.string(from: day)
        return validDayKeys.contains(key)
    }

    private func fetchValidDates(for month: Date) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }

        let startKey = DateFormatter.appDayKey.string(from: interval.start)
        let endKey = DateFormatter.appDayKey.string(from: interval.end.addingTimeInterval(-1))

        Firestore.firestore().collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isGreaterThanOrEqualTo: startKey)
            .whereField("createdAt", isLessThanOrEqualTo: endKey)
            .getDocuments { snap, _ in
                let keys = snap?.documents.compactMap { doc -> String? in
                    if let s = doc.data()["createdAt"] as? String {
                        return s
                    }
                    if let ts = doc.data()["createdAt"] as? Timestamp {
                        return DateFormatter.appDayKey.string(from: ts.dateValue())
                    }
                    return nil
                } ?? []

                if !keys.isEmpty {
                    DispatchQueue.main.async {
                        validDayKeys = Set(keys)
                    }
                    return
                }

                // Fallback for mixed types: fetch by uid only, then filter in-memory by month.
                Firestore.firestore().collection("daily_recommendation")
                    .whereField("uid", isEqualTo: uid)
                    .getDocuments { fallbackSnap, _ in
                        let fallbackKeys = fallbackSnap?.documents.compactMap { doc -> String? in
                            if let s = doc.data()["createdAt"] as? String {
                                return s
                            }
                            if let ts = doc.data()["createdAt"] as? Timestamp {
                                return DateFormatter.appDayKey.string(from: ts.dateValue())
                            }
                            return nil
                        } ?? []

                        let filtered = fallbackKeys.filter { key in
                            key >= startKey && key <= endKey
                        }

                        DispatchQueue.main.async {
                            validDayKeys = Set(filtered)
                        }
                    }
            }
    }

    private func sanitizeNotesText(_ value: String) -> String {
        let prefixes = [
            "Mood:",
            "Stress:",
            "Sleep:",
            "Emotional Source:"
        ]
        let lines = value.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !prefixes.contains { trimmed.hasPrefix($0) }
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(dailyVM: DailyViewModel = DailyViewModel(),
         enableLoading: Bool = true) {
        _dailyVM = StateObject(wrappedValue: dailyVM)
        self.enableLoading = enableLoading
    }
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var reasoningStore: DailyReasoningStore
    
    @Environment(\.dismiss) private var dismiss
//    @State private var headerHeight: CGFloat = 0
    
    private var mantraText: String {
        dailyVM.mantra.isEmpty
            ? "Your daily mantra will appear here."
            : dailyVM.mantra
    }

    private var indentedMantra: AttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributed = NSAttributedString(
            string: mantraText,
            attributes: [.paragraphStyle: paragraphStyle]
        )

        return AttributedString(attributed)
    }

    private func sectionHeader(title: String, systemName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.accent)

            Text(title)
                .font(AlynnaTypography.font(.headline))
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                AppBackgroundView()
                    .ignoresSafeArea()
        
                
                ScrollView(.vertical, showsIndicators: false) {
                    TimelineHeader(title: "Timeline") { dismiss() }
                                            .padding(.bottom, 4)
                                            .foregroundColor(themeManager.foregroundColor)
                    
                    VStack(spacing: 12) {
                        CalendarView(
                            selectedDate: $selectedDate,
                            accentColor: themeManager.accent,
                            isDateEnabled: { isDateSelectable($0) },
                            onMonthChange: { fetchValidDates(for: $0) }
                        )
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(themeManager.panelFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [themeManager.panelStrokeHi, themeManager.panelStrokeLo],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                        .shadow(color: .black.opacity(themeManager.isNight ? 0.12 : 0.10), radius: 10, y: 6)
                        .cornerRadius(18)
                        .onAppear {
                            fetchValidDates(for: selectedDate)
                            loadTimelineContent(for: selectedDate)
                        }
                        .onChange(of: selectedDate) {
                            loadTimelineContent(for: selectedDate)
                        }

                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Rectangle()
                                .fill(themeManager.descriptionText.opacity(0.2))
                                .frame(height: 1)

                            Text(DateFormatter.appLong.string(from: selectedDate))
                                .font(AlynnaTypography.font(.caption1))
                                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                        }
                        .padding(.horizontal, 16)
                        
                        sectionHeader(title: "Journal", systemName: "book.closed")

                        NavigationLink {
                            JournalView(date: selectedDate)
                                .environmentObject(themeManager)
                                .environmentObject(starManager)
                                .environmentObject(viewModel)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text("Last entry")
                                            .font(AlynnaTypography.font(.headline))
                                            .foregroundColor(themeManager.primaryText)
                                            .lineLimit(1)

                                        Spacer(minLength: 12)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(themeManager.descriptionText.opacity(0.8))
                                    }

                                    if isLoadingJournal {
                                        Text("Loading…")
                                            .font(AlynnaTypography.font(.subheadline))
                                            .foregroundColor(themeManager.descriptionText)
                                    } else if journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("No entry yet.")
                                            .font(AlynnaTypography.font(.subheadline))
                                            .foregroundColor(themeManager.descriptionText)
                                    } else {
                                        Text(journalText)
                                            .font(AlynnaTypography.font(.subheadline))
                                            .foregroundColor(themeManager.descriptionText)
                                            .lineLimit(2)
                                            .truncationMode(.tail)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        themeManager.isNight
                                        ? Color.white.opacity(0.06)
                                        : Color.black.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        sectionHeader(title: "Mantra", systemName: "quote.bubble")

                        VStack(alignment: .leading, spacing: 8) {
                            if dailyVM.mantra.isEmpty {
                                Text("No mantra for this day.")
                                    .font(AlynnaTypography.font(.subheadline))
                                    .foregroundColor(themeManager.descriptionText)
                            } else {
                                Text(indentedMantra)
                                    .font(AlynnaTypography.font(.body))
                                    .italic()
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(
                                        themeManager.isNight
                                        ? themeManager.primaryText.opacity(0.9)
                                        : themeManager.primaryText.opacity(0.8)
                                    )
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(themeManager.panelFill.opacity(0.75))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(themeManager.panelStrokeHi.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)

                        sectionHeader(title: "Rhythm", systemName: "waveform")

                        // Build an ordered list of items for the categories you care about
                        let dayItems: [SuggestionItem] = allCategories.compactMap { cat in
                            dailyVM.items.first(where: { $0.category == cat })
                        }

                        Group {
                            if dayItems.isEmpty {
                                NoDataMessage(date: selectedDate)
                                    .environmentObject(themeManager)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                                    ForEach(dayItems, id: \.id) { item in
                                        Button {
                                            selectedSuggestion = item
                                        } label: {
                                            SuggestionRow(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .id(selectedDate)
                    }
                    .frame(width: geometry.size.width, alignment: .top)
                    .padding(.top)
                }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedSuggestion) { item in
                TimelineSuggestionDetailSheet(item: item)
            }
        }
    }
}

#if DEBUG

private struct ContentViewPreviewContainer: View {
    let isNight: Bool
    let dailyVM: DailyViewModel
    let enableLoading: Bool

    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var reasoningStore = DailyReasoningStore()

    init(isNight: Bool, dailyVM: DailyViewModel, enableLoading: Bool) {
        self.isNight = isNight
        self.dailyVM = dailyVM
        self.enableLoading = enableLoading

        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)

        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel())
    }

    var body: some View {
        TimelineView(dailyVM: dailyVM, enableLoading: enableLoading)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .environmentObject(onboardingViewModel)
            .environmentObject(reasoningStore)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Calendar • Dark Filled") {
    ContentViewPreviewContainer(
        isNight: true,
        dailyVM: .filledPreview,
        enableLoading: false
    )
}

#Preview("Calendar • Light Filled") {
    ContentViewPreviewContainer(
        isNight: false,
        dailyVM: .filledPreview,
        enableLoading: false
    )
}

#Preview("Calendar • Dark Empty") {
    ContentViewPreviewContainer(
        isNight: true,
        dailyVM: DailyViewModel(),
        enableLoading: false
    )
}

private extension DailyViewModel {
    static var filledPreview: DailyViewModel {
        let vm = DailyViewModel()
        vm.mantra = "With the bright afternoon sun and the air felling a bit heavy, today is about finding your center amidst a lot of outward movement."
        vm.items = [
            .preview("Place",        "Open Flow",      "Take a walk by the river"),
            .preview("Color",        "Rose",           "Use rosy tones today"),
            .preview("Gemstone",     "Moonstone",      "Keep grounding energy"),
            .preview("Scent",        "Bergamot",       "Light a bergamot candle"),
            .preview("Activity",     "Journaling",     "Reflect in writing"),
            .preview("Sound",        "Ocean Waves",    "Play soothing audio"),
            .preview("Career",       "Gentle Start",   "Begin with a small task"),
            .preview("Relationship", "Quiet Together", "Share calm time")
        ]
        return vm
    }
}

extension SuggestionItem {
    static func preview(_ category: String, _ title: String, _ description: String) -> SuggestionItem {
        SuggestionItem(
            id: "\(category)-\(UUID().uuidString.prefix(8))",
            category: category,
            title: title,
            description: description
        )
    }
}
#endif
