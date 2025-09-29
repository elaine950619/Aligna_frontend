//
//  ContentView.swift
//
//
//  Created by Elaine Hsieh on 6/29/25.
//

import SwiftUI

private struct TimelineHeader: View {
    var title: String = "Timeline"
    var onBack: () -> Void

    var body: some View {
        GeometryReader { geo in
            // use safe-area top for exact placement under the notch
            let top = geo.safeAreaInsets.top
            var extraTop: CGFloat = 20

            ZStack {
                Spacer()
                // centered title
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.95))
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

                // back button (leading)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(8)
                            .background(
                                Circle().fill(Color.black.opacity(0.25))
                            )
                    }
                    .contentShape(Rectangle())
                    Spacer()
                }
            }
            .padding(.top, max(top, 12) + extraTop)
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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                // Category pill (uppercase), right‑aligned
                Text(item.category)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
//                    .background(
//                        Capsule().fill(Color.white.opacity(0.10))
//                    )
//                    .overlay(
//                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8)
//                    )
                    .foregroundColor(themeManager.accent)
            }

            // Description (muted, single line like your React list)
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        // Card container to match the React “soft panel”
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
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
    private let enableLoading: Bool

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
                    
                    VStack(spacing: 24) {
                        // make room for the header
//                        Spacer().frame(height: 96)    try 88–104 to taste
                        
                        CalendarView(
                            selectedDate: $selectedDate,
                            accentColor: .accentColor
                        )
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                        )
                        .cornerRadius(20)
                        .onAppear {
                            if enableLoading { dailyVM.load(for: selectedDate) }
                        }
                        .onChange(of: selectedDate) {
                            if enableLoading { dailyVM.load(for: selectedDate) }
                        }
                        .padding(.horizontal, 16)
                        
                        Group {
                            if dailyVM.mantra.isEmpty {
                                Text("Your daily mantra will appear here.")
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text(dailyVM.mantra)
                                    .italic()
                                    .padding(.horizontal)
//                                    .colorInvert()
                            }
                        }
                        .id(selectedDate)
                        
                        // one‑column grid of full‑width capsules
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                            ForEach(allCategories, id: \.self) { category in
                                if let item = dailyVM.items.first(where: { $0.category == category }) {
                                    // real data
                                    SuggestionRow(item: item)
                                } else {
                                    // placeholder skeleton
                                    PlaceholderRow(category: category)
                                        .redacted(reason: .placeholder)  // iOS 15+ greyed-out look
                                }
                            }
                        }
                        .padding(.horizontal, 16)  // outer margin
                    }
                    .padding(.top)
                }
//                .safeAreaPadding(.top, headerHeight)
            }
//            .safeAreaInset(edge: .top, spacing: -20) {
//
//                TimelineHeader(title: "Timeline") { dismiss() }
//            }

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


