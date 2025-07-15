//
//  CalendarView.swift
//
//
//  Created by Elaine Hsieh on 6/29/25.
//

import SwiftUI

struct Suggestion: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
}
final class SuggestionVM: ObservableObject {
    @Published var items: [Suggestion] = [
        .init(title: "Place", iconName: "icon_place"),
        .init(title: "Gemstone", iconName: "icon_gemstone"),
        .init(title: "Color", iconName: "icon_color"),
        .init(title: "Scent", iconName: "icon_scent"),
        .init(title: "Activity", iconName: "icon_activity"),
        .init(title: "Sound", iconName: "icon_sound"),
        .init(title: "Career", iconName: "icon_career"),
        .init(title: "Relationship", iconName: "icon_relationship")
    ]
}
private struct SuggestionChip: View {
    let title: String
    let iconName: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(iconName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ContentView: View {
  @State private var selectedDate = Date()
  @StateObject private var vm = SuggestionVM()
  @EnvironmentObject var starManager: StarAnimationManager
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    GeometryReader { geo in
      ZStack {
        AppBackgroundView().environmentObject(starManager)
        ScrollView {
          VStack(spacing: 24) {
            // ← here’s your new SwiftUI CalendarView
            CalendarView(selectedDate: $selectedDate)
              .frame(height: 330)
              .padding(.horizontal)
              .background(Color(.secondarySystemBackground)) 
              .cornerRadius(20)

            // ← then your chips grid
              LazyVGrid(
                  columns: [.init(.flexible(), spacing: 16), .init(.flexible(), spacing: 16)],
                  spacing: 16
              ) {
              ForEach(vm.items) { item in
                SuggestionChip(title: item.title, iconName: item.iconName)
              }
            }
          }
          .padding(.vertical)
          .padding(.top, geo.safeAreaInsets.top + 8)
        }
      }
      .ignoresSafeArea(edges: .vertical)
      .navigationTitle("Calendar")
      .onAppear {
        starManager.animateStar = true
        themeManager.updateTheme()
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(StarAnimationManager())
    .environmentObject(ThemeManager())
}
