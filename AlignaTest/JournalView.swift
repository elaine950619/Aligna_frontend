//
//  JournalView.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/25/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

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
    guard let userId = Auth.auth().currentUser?.uid else {
      print("❌ No user")
      return
    }

    let dateString = self.dateString
    let db = Firestore.firestore()
    
    db.collection("daily_recommendation")
      .whereField("uid",        isEqualTo: userId)
      .whereField("createdAt",  isEqualTo: dateString)
      .getDocuments { snap, err in
        if let err = err {
          print("❌ lookup rec failed:", err); return
        }
        guard let doc = snap?.documents.first else {
          print("❌ no rec doc for today"); return
        }
        
        let journalsRef = db
          .collection("daily_recommendation")
          .document(doc.documentID)
          .collection("journals")
        
        journalsRef.addDocument(data: [
          "text":       self.text,
          "createdAt":  Timestamp()
        ]) { err in
          if let err = err {
            print("❌ Failed to save journal:", err)
          } else {
            print("✅ Journal saved!")
            DispatchQueue.main.async {
              self.presentationMode.wrappedValue.dismiss()
            }
          }
        }
      }
  }
}
