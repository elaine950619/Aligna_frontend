//
//  JournalView.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/25/25.
//

import SwiftUI
import FirebaseFirestore

struct JournalView: View {
  let date: Date
  @State private var text: String = ""
  @Environment(\.presentationMode) private var presentationMode
  @EnvironmentObject var themeManager: ThemeManager
  
  private var dateString: String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: date)
  }
  
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
    let db = Firestore.firestore()
    let journalRef = db
      .collection("daily_recommendation")
      .document(dateString)
      .collection("journals")
    
    journalRef.addDocument(data: [
      "text": text,
      "createdAt": Timestamp()
    ]) { error in
      if let error = error {
        print("❌ Failed to save journal:", error)
      } else {
        print("✅ Journal saved!")
      }
    }
  }
}
