//
//  CalendarView.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/20/25.
//

import SwiftUI
import Foundation

enum MoonPhase: String, CaseIterable {
    case new, waxingcrescent, firstquarter, waxinggibbous,
         full, waninggibbous, lastquarter, waningcrescent
}

// Meeus JD + simple synodic phase bucket
func julianDay(from date: Date) -> Double {
    let cal = Calendar(identifier: .gregorian)
    let c = cal.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
    var Y = c.year!, M = c.month!
    let D = Double(c.day!) + Double(c.hour!)/24 + Double(c.minute!)/1440 + Double(c.second!)/86400
    if M <= 2 { Y -= 1; M += 12 }
    let A = floor(Double(Y)/100), B = 2 - A + floor(A/4)
    return floor(365.25*Double(Y+4716)) + floor(30.6001*Double(M+1)) + D + B - 1524.5
}

func computeMoonPhase(on date: Date) -> MoonPhase {
    let jd = julianDay(from: date)
    let refNewMoon = 2451550.1
    let synodic = 29.53058867
    let cyclePos = ( (jd - refNewMoon) / synodic ).truncatingRemainder(dividingBy: 1)
    let idx = Int(floor( (cyclePos < 0 ? cyclePos + 1 : cyclePos) * 8 )) % 8
    return MoonPhase.allCases[idx]
}

// Map to SF Symbols moonphase icons (uses iOS 16+)
func moonSymbol(for phase: MoonPhase) -> String {
    switch phase {
    case .new:             return "moonphase.new.moon.inverse"
    case .waxingcrescent:  return "moonphase.waxing.crescent.inverse"
    case .firstquarter:    return "moonphase.first.quarter.inverse"
    case .waxinggibbous:   return "moonphase.waxing.gibbous.inverse"
    case .full:            return "moonphase.full.moon.inverse"
    case .waninggibbous:   return "moonphase.waning.gibbous.inverse"
    case .lastquarter:     return "moonphase.last.quarter.inverse"
    case .waningcrescent:  return "moonphase.waning.crescent.inverse"
    }
}

// Month grid builder
func makeCalendarGrid(for month: Date, calendar: Calendar = .current) -> [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: month),
          let firstWD = calendar.dateComponents([.weekday], from: interval.start).weekday else { return [] }
    let days = calendar.range(of: .day, in: .month, for: interval.start)!
    let leading = Array(repeating: Optional<Date>(nil), count: firstWD - 1)
    let monthDates = days.map { d in calendar.date(byAdding: .day, value: d - 1, to: interval.start)! }
    let total = leading.count + monthDates.count
    let trailing = Array(repeating: Optional<Date>(nil), count: (7 - (total % 7)) % 7)
    return leading + monthDates.map { Optional($0) } + trailing
}

struct DayCell: View {
    let date: Date?
    let isSelected: Bool
    let accent: Color
    let tap: ()->Void

    @EnvironmentObject var themeManager: ThemeManager   // ← add

    var body: some View {
        if let date {
            let day   = Calendar.current.component(.day, from: date)
            let phase = computeMoonPhase(on: date)

            Button(action: tap) {
                VStack(spacing: 1) {
                    ZStack {
                        // gold moon stays as-is
                        Image(systemName: moonSymbol(for: phase))
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow.opacity(0.95), .orange.opacity(0.9)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )

                        // selection ring uses your accent
                        Circle()
                            .stroke(isSelected ? accent : .clear, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    // day label uses your theme primary text
                    Text("\(day)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.primaryText.opacity(0.9))   // ← was white
                }
                .frame(width: 44)
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 6) {
                Color.clear.frame(width: 36, height: 36)
                Text(" ").font(.system(size: 11))
            }
            .frame(width: 44)
        }
    }
}



struct CalendarView: View {
    @Binding var selectedDate: Date
    var accentColor: Color = .accentColor

    @EnvironmentObject var themeManager: ThemeManager    // ← add

    @State private var displayMonth: Date = Date()
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button { prevMonth() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.foregroundColor)          // ← was white
                        .padding(8)
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(themeManager.primaryText)                  // ← was white
                Spacer()
                Button { nextMonth() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.foregroundColor)          // ← was white
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
            }

            // Weekday row
            HStack {
                ForEach(shortWeekdaySymbols, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.descriptionText.opacity(0.9)) // ← was white
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(makeCalendarGrid(for: displayMonth).enumerated()), id: \.offset) { _, d in
                    DayCell(
                        date: d,
                        isSelected: d.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false,
                        accent: accentColor
                    ) {
                        if let d { selectedDate = d }
                    }
                    .environmentObject(themeManager)   // ← pass through
                }
            }
        }
        .padding(4)
    }
    
    private func prevMonth() { displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)! }
    private func nextMonth() { displayMonth = calendar.date(byAdding: .month, value:  1, to: displayMonth)! }
    
    private var monthTitle: String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: displayMonth)
    }
    
    private var shortWeekdaySymbols: [String] {
        // Force Sun-first like the mock
        var syms = calendar.shortWeekdaySymbols // ["Sun","Mon",...]
        // Convert to "Su", "Mo", ...
        syms = syms.map { String($0.prefix(2)) }
        return syms
    }
}

