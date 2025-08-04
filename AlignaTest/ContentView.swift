//
//  CalendarView.swift
//
//
//  Created by Elaine Hsieh on 6/29/25.
//

import SwiftUI

// Tiny row view to offload icon + text layout
struct SuggestionRow: View {
    let item: SuggestionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // category
            Text(item.category)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            // icon, title
            HStack {
                // try your real asset first
                if let ui = UIImage(named: item.assetName) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.accentColor)
                } else {
                    // fallback
                    Image(systemName: "photo")
                        .frame(width: 24, height: 24)
                        .foregroundColor(.secondary)
                }
                
                Text(item.title)
                    .font(.subheadline).bold()
                
                Spacer()
            }
            
            Text(item.description)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        //    .clipShape(Capsule())
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
    @StateObject private var dailyVM = DailyViewModel()
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                    .ignoresSafeArea()
                
//                CustomBackButton(
//                    iconSize: 18,
//                    paddingSize: 8,
//                    backgroundColor: Color.black.opacity(0.3),
//                    iconColor: themeManager.foregroundColor,
//                    topPadding: 44,
//                    horizontalPadding: 24
//                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        CalendarView(
                            selectedDate: $selectedDate,
                            accentColor: .accentColor
                        )
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .onAppear { dailyVM.load(for: selectedDate) }
                        .onChange(of: selectedDate) {
                            dailyVM.load(for: selectedDate)
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
                                    .colorInvert()
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
            }
            .navigationTitle("Calendar")
        }
    }
}
