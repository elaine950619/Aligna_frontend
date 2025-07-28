//
//  CalendarView.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/20/25.
//

import SwiftUI
import Foundation

struct RecommendationResponse: Decodable {
  let mantra: String
  let sentiment: String
  let recommendations: [String:String]
}


enum MoonPhase: String, CaseIterable {
  case new
  case waxingcrescent
  case firstquarter
  case waxinggibbous
  case full
  case waninggibbous
  case lastquarter
  case waningcrescent
}

/// 1. JD formula from “Astronomical Algorithms” by Jean Meeus
func julianDay(from date: Date) -> Double {
  let cal = Calendar(identifier: .gregorian)
  let components = cal.dateComponents(
    [.year, .month, .day,
     .hour, .minute, .second],
    from: date
  )
  var Y = components.year!
  var M = components.month!
  var D = Double(components.day!)
       + Double(components.hour!)   / 24.0
       + Double(components.minute!) / 1440.0
       + Double(components.second!) / 86400.0

  if M <= 2 {
    Y -= 1
    M += 12
  }

  let A = floor(Double(Y)  / 100.0)
  let B = 2 - A + floor(A / 4.0)

  let jd = floor(365.25 * Double(Y + 4716))
         + floor(30.6001 * Double(M + 1))
         + D + B - 1524.5

  return jd
}

/// 2. Compute phase index
func computeMoonPhase(on date: Date) -> MoonPhase {
  let jd = julianDay(from: date)

  // Reference new moon epoch (2000 Jan 6.0)
  let refNewMoon = 2451550.1
  let synodicMonth = 29.53058867

  let daysSinceNew = jd - refNewMoon
  let newMoons = daysSinceNew / synodicMonth
  let cyclePos = newMoons - floor(newMoons)    // fraction [0,1)

  // 8 phases -> multiply, floor, mod 8
  let index = Int(floor(cyclePos * 8.0)) % 8

  return MoonPhase.allCases[index]
}

func makeCalendarGrid(for month: Date, calendar: Calendar = .current) -> [Date?] {
  // 1) start of month
  guard let monthInterval = calendar.dateInterval(of: .month, for: month),
        let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
  else { return [] }

  // 2) how many days in month
  let days = calendar.range(of: .day, in: .month, for: monthInterval.start)!
  
  // 3) add leading nils to align the first day to its weekday
  let leadingBlanks: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

  // 4) map day numbers to actual Date objects
  let monthDates = days.map { day -> Date in
    calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)!
  }
  
  // 5) trailing blanks to fill out the final row
  let total = leadingBlanks.count + monthDates.count
  let trailingBlanks: [Date?] = Array(repeating: nil,
                                       count: (7 - (total % 7)) % 7)
  
  return leadingBlanks + monthDates.map { Optional($0) } + trailingBlanks
}

struct DayCell: View {
  let date: Date?
  let isSelected: Bool
  let action: ()->Void

  var body: some View {
    if let date = date {
      let day = Calendar.current.component(.day, from: date)

      Button(action: action) {
        ZStack {
          // A. Full‐circle background (matches the card colour)
          Circle()
            .fill(Color(.secondarySystemBackground))
            .frame(width: 44, height: 44)

          // B. Moon image, filling the circle
          Image("moon_\(computeMoonPhase(on: date).rawValue)")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(Circle())

          // C. Day number centered
          Text("\(day)")
            .font(.caption2)
            .foregroundColor(.white)
//            .shadow(color: .black.opacity(0.6), radius: 0.5, x: 0, y: 0)

          // D. Selection ring on top
          Circle()
            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            .frame(width: 44, height: 44)
        }
      }
      .buttonStyle(PlainButtonStyle())
      .frame(width: 44, height: 44)

    } else {
      // blank placeholder: keep the same size
      Color.clear
        .frame(width: 44, height: 44)
    }
  }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    var accentColor: Color
    
    @State private var displayMonth: Date = Date()
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. Month header
            HStack {
                Button { prevMonth() } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button { nextMonth() } label: {
                    Image(systemName: "chevron.right")
                }
            }
//            .padding(.horizontal, 24)
            
            // 2. Weekday symbols
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { wd in
                    Text(wd)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            
            // 3. Day grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(makeCalendarGrid(for: displayMonth).enumerated()),
                        id: \.offset) { _, maybeDate in
                  DayCell(
                    date: maybeDate,
                    isSelected: maybeDate.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false
                    
                  ) {
                    if let d = maybeDate {
                      selectedDate = d
                    }
                  }
                }
            }
        }
        .padding(.horizontal, 24)
//        .foregroundColor(.white)
    }
    
    // advance or rewind the displayed month
    private func prevMonth() {
        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
    }
    private func nextMonth() {
        displayMonth = calendar.date(byAdding: .month, value:  1, to: displayMonth)!
    }
    
    private var monthTitle: String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: displayMonth)
    }
}
