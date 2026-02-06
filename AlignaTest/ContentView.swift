//
//  ContentView.swift
//
//
//  Created by Elaine Hsieh on 6/29/25.
//

import SwiftUI
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
                .font(TimelineType.cardTitle18MerriweatherBlack())
                .lineSpacing(TimelineType.cardTitle18LineSpacing)
                .foregroundColor(themeManager.primaryText)

            Text(DateFormatter.appLong.string(from: date))
                .font(TimelineType.cardBody14MerriweatherRegular())
                .lineSpacing(TimelineType.cardBody14LineSpacing)
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
            var extraTop: CGFloat = 10

            ZStack {
                
                // back button (leading)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(themeManager.foregroundColor)
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


                    // subtle underline "glow"
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ .white.opacity(0.0),
                                          .white.opacity(0.55),
                                          .white.opacity(0.0) ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 2)
                        .blur(radius: 0.3)
                        .offset(y: -2)
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
        VStack(alignment: .leading, spacing: 8) {
            // Top row: icon • title • category chip (right)
            HStack(spacing: 12) {
                // Icon (fixed size, template tint)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)

                    if !iconName.isEmpty, UIImage(named: iconName) != nil {
                        Image(iconName)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(themeManager.accent)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.accent)
                    }
                }

                // Title
                Text(item.title)
                    .font(TimelineType.cardTitle18MerriweatherBlack())
                    .lineSpacing(TimelineType.cardTitle18LineSpacing)
                    .foregroundColor(themeManager.primaryText)   // <-- avoid .primary so it matches theme
                    .lineLimit(1)

                Spacer(minLength: 12)

                // Category pill (uppercase), right‑aligned
                Text(item.category)
                    .font(TimelineType.tag14MerriweatherLight())
                    .lineSpacing(TimelineType.tag14LineSpacing)
                    .tracking(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundColor(themeManager.accent)
            }

            // Description (muted, single line like your React list)
            if !item.description.isEmpty {
                Text(item.description)
                    .font(TimelineType.cardBody14MerriweatherRegular())
                    .lineSpacing(TimelineType.cardBody14LineSpacing)
                    .foregroundColor(themeManager.descriptionText)
                    .lineLimit(1)
            }
        }
        // Card container to match the React “soft panel”
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
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



struct PlaceholderRow: View {
    let category: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category)
                .font(.headline)
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

struct ContentView: View {
    private let allCategories = [
        "Place","Color","Gemstone","Scent",
        "Activity","Sound","Career","Relationship"
    ]
    
    @State private var selectedDate = Date()
    @StateObject private var dailyVM: DailyViewModel
    @State private var journalText: String = ""
    @State private var isLoadingJournal: Bool = false

    
    private let enableLoading: Bool
    
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
                                journalText = jSnap?.documents.first?.data()["text"] as? String ?? ""
                            }
                        }
                } else {
                    // 2) fallback: users/{uid}/journals/{yyyy-MM-dd}
                    db.collection("users").document(uid)
                        .collection("journals").document(ds)
                        .getDocument { doc, _ in
                            DispatchQueue.main.async {
                                isLoadingJournal = false
                                journalText = (doc?.data()?["text"] as? String) ?? ""
                            }
                        }
                }
            }
    }

    init(dailyVM: DailyViewModel = DailyViewModel(),
         enableLoading: Bool = true) {
        _dailyVM = StateObject(wrappedValue: dailyVM)
        self.enableLoading = enableLoading
    }
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @Environment(\.dismiss) private var dismiss
//    @State private var headerHeight: CGFloat = 0
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                    .ignoresSafeArea()
        
                
                ScrollView(showsIndicators: false) {
                    TimelineHeader(title: "Timeline") { dismiss() }
                                            .padding(.bottom, 8)
                                            .foregroundColor(themeManager.foregroundColor)
                    
                    VStack(spacing: 24) {

                        CalendarView(
                            selectedDate: $selectedDate,
                            accentColor: themeManager.accent          // use your themed accent
                        )
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                        .cornerRadius(20)
                        .onAppear {
                            if enableLoading { dailyVM.load(for: selectedDate) }
                            loadJournal(for: selectedDate)
                        }
                        .onChange(of: selectedDate) {
                            if enableLoading { dailyVM.load(for: selectedDate) }
                            loadJournal(for: selectedDate)
                        }

                        .padding(.horizontal, 16)
                        
                        Group {
                            Text(dailyVM.mantra.isEmpty
                                 ? "Your daily mantra will appear here."
                                 : dailyVM.mantra)
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                // use existing theme colors (no new palette)
                                .foregroundColor(
                                    dailyVM.mantra.isEmpty
                                    ? themeManager.descriptionText.opacity(0.9)       // placeholder = muted
                                    : (themeManager.isNight
                                        ? themeManager.primaryText.opacity(0.9)       // night = bright cream
                                        : themeManager.primaryText.opacity(0.8))      // light = warm brown, softened
                                )
                        }
                        .id(selectedDate)
                        
                        // Build an ordered list of items for the categories you care about
                        let dayItems: [SuggestionItem] = allCategories.compactMap { cat in
                            dailyVM.items.first(where: { $0.category == cat })
                        }

                        // If there are NO items (and optionally no mantra), show the message
                        if dayItems.isEmpty /* && dailyVM.mantra.isEmpty */ {
                            NoDataMessage(date: selectedDate)
                                .environmentObject(themeManager)
                        } else {
                            // Show only the items that exist — no placeholders
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                                ForEach(dayItems, id: \.id) { item in
                                    SuggestionRow(item: item)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top)
                    
                    // --- Journal panel at bottom ---
                    NavigationLink {
                        JournalView(date: selectedDate)
                            .environmentObject(themeManager)
                            .environmentObject(starManager)
                            .environmentObject(viewModel)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeManager.accent)

                                Text("Journal")
                                    .font(TimelineType.cardTitle18MerriweatherBlack())
                                    .lineSpacing(TimelineType.cardTitle18LineSpacing)
                                    .foregroundColor(themeManager.primaryText)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.8))
                            }

                            if isLoadingJournal {
                                Text("Loading…")
                                    .font(TimelineType.cardBody14MerriweatherRegular())
                                    .lineSpacing(TimelineType.cardBody14LineSpacing)
                                    .foregroundColor(themeManager.descriptionText)
                            } else if journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Tap to write your daily check-in…")
                                    .font(TimelineType.cardBody14MerriweatherRegular())
                                    .lineSpacing(TimelineType.cardBody14LineSpacing)
                                    .foregroundColor(themeManager.descriptionText)
                            } else {
                                Text(journalText)
                                    .font(TimelineType.cardBody14MerriweatherRegular())
                                    .lineSpacing(TimelineType.cardBody14LineSpacing)
                                    .foregroundColor(themeManager.descriptionText)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(themeManager.panelFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(themeManager.isNight ? 0.12 : 0.10), radius: 10, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#if DEBUG

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(dailyVM: filledDailyVM, enableLoading: false)
                .environmentObject(StarAnimationManager())
                .environmentObject(previewTheme)
                .environmentObject(previewOnboarding)
                .preferredColorScheme(.dark)
                .previewDisplayName("Calendar • Dark Filled")

            ContentView(dailyVM: filledDailyVM, enableLoading: false)
                .environmentObject(StarAnimationManager())
                .environmentObject(previewThemeLight)
                .environmentObject(previewOnboarding)
                .preferredColorScheme(.light)
                .previewDisplayName("Calendar • Light Filled")

            // Dark scheme empty (placeholders only)
            ContentView()
                .environmentObject(StarAnimationManager())
                .environmentObject(previewTheme)
                .environmentObject(previewOnboarding)
                .preferredColorScheme(.dark)
                .previewDisplayName("Calendar • Dark Empty")
        }
    }

    // MARK: - Preview Seeds

    private static var previewTheme: ThemeManager { ThemeManager() }
    private static var previewThemeLight: ThemeManager { ThemeManager() }

    private static var previewOnboarding: OnboardingViewModel {
        let vm = OnboardingViewModel()
        vm.recommendations = [
            "Place": "ic_place",
            "Color": "ic_color",
            "Gemstone": "ic_gem",
            "Scent": "ic_scent",
            "Activity": "ic_activity",
            "Sound": "ic_sound",
            "Career": "ic_career",
            "Relationship": "ic_relationship"
        ]
        return vm
    }

    private static var filledDailyVM: DailyViewModel {
        let vm = DailyViewModel()
        vm.mantra = "Breathe. Align. Begin again."
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
