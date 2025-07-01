//
//  ContentView.swift
//  
//
//  Created by Elaine Hsieh on 6/29/25.
//


import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date()

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                VStack(spacing: 20) {
                    Spacer().frame(height: geometry.size.height * 0.05)

                    Text("📅 Select a Date")
                        .font(Font.custom("PlayfairDisplay-Regular", size: min(geometry.size.width, geometry.size.height) * 0.06))
                        .foregroundColor(themeManager.foregroundColor)

                    CalendarView(
                        selectedDate: $selectedDate,
                        backgroundColor: UIColor(themeManager.foregroundColor)
                    )
                    .frame(height: 330)
                    .padding(.horizontal)


                    VStack(spacing: 8) {
                        Text("You selected:")
                            .font(.headline)
                            .foregroundColor(themeManager.foregroundColor)

                        Text("\(formattedDate(date: selectedDate))")
                            .font(.body)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.8))
                    }

                    Button(action: {
                        print("✅ Date confirmed: \(selectedDate)")
                        // Handle your navigation or logic here
                    }) {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(themeManager.foregroundColor)
                            .cornerRadius(12)
                            .padding(.horizontal, geometry.size.width * 0.1)
                    }
                    .padding(.top, 20)

                    Spacer()
                }
                .padding(.bottom)
            }
            .onAppear {
                starManager.animateStar = true
                themeManager.updateTheme()
            }
        }
    }

    func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
