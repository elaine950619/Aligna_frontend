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
    @State private var journalDocID: String? = nil
    @State private var recommendationDocID: String? = nil
    @Environment(\ .presentationMode) private var presentationMode
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal for \(formattedDate)")
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
        .onAppear {
            loadEntry()
        }
    }

    private func loadEntry() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user")
            return
        }
        let ds = dateString
        let db = Firestore.firestore()
        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: ds)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ lookup rec failed:", error)
                    return
                }
                guard let recDoc = snapshot?.documents.first else {
                    print("❌ no rec doc for today")
                    return
                }
                recommendationDocID = recDoc.documentID
                let journalsRef = db
                    .collection("daily_recommendation")
                    .document(recDoc.documentID)
                    .collection("journals")
                journalsRef
                    .order(by: "createdAt", descending: false)
                    .limit(to: 1)
                    .getDocuments { journSnap, journErr in
                        if let journErr = journErr {
                            print("❌ lookup journal failed:", journErr)
                            return
                        }
                        guard let journDoc = journSnap?.documents.first else {
                            // no journal yet
                            return
                        }
                        journalDocID = journDoc.documentID
                        text = journDoc.data()["text"] as? String ?? ""
                    }
            }
    }

    private func saveEntry() {
        guard let recID = recommendationDocID else {
            print("❌ No recommendation document found for today")
            return
        }
        let db = Firestore.firestore()
        let journalsRef = db
            .collection("daily_recommendation")
            .document(recID)
            .collection("journals")
        if let journalID = journalDocID {
            // update existing
            journalsRef.document(journalID).updateData([
                "text": text
            ]) { error in
                if let error = error {
                    print("❌ Failed to update journal:", error)
                } else {
                    print("✅ Journal updated!")
                }
            }
        } else {
            // create new
            journalsRef.addDocument(data: [
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
}
