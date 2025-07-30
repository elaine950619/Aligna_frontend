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
    .clipShape(Capsule())
  }
}

struct ContentView: View {
  @State private var selectedDate = Date()
  @StateObject private var dailyVM = DailyViewModel()
  @EnvironmentObject var starManager: StarAnimationManager
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackgroundView()
          .ignoresSafeArea()

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

//            NavigationLink {
//              JournalView(date: selectedDate)
//            } label: {
//              Text("Have something to say?")
//                .padding(.vertical, 8)
//                .padding(.horizontal, 16)
//                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
//                .foregroundColor(.accentColor)
//            }

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

            // one‑column grid of full‑width capsules
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 4) {
              ForEach(dailyVM.items) { item in
                SuggestionRow(item: item)
              }
            }
            .padding(.horizontal)
          }
          .padding(.top)
        }
      }
      .navigationTitle("Calendar")
    }
  }
}
