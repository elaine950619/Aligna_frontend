//
//  JournalView.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/25/25.
//

import SwiftUI

struct JournalView: View {
    let date: Date
    @State private var text: String = ""
    @Environment(\.presentationMode) private var presentationMode
    
    private var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .full
        return df.string(from: date)
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing: 16) {
            Text("Journal for for \(formattedDate)")
                .font(.headline)
                .padding(.top)
            TextEditor(text: $text)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Save") {
                    saveEntry()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Journal")
    }
    
    private func saveEntry() {
        let key = "journal_\(Calendar.current.component(.day, from: date))_" +
                  "\(Calendar.current.component(.month, from: date))_" +
                  "\(Calendar.current.component(.year, from: date))"
        UserDefaults.standard.set(text, forKey: key)
    }
}
