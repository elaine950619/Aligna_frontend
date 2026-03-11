//
//  DailyViewModel.swift
//  AlignaTest
//
//  Created by Elaine Hsieh on 7/28/25.
//

import FirebaseFirestore
import Combine
import FirebaseAuth

struct SuggestionItem: Identifiable {
    let id: String            // e.g. "Place-F7qJq41pACtid7QaIHHD"
    let category: String      // e.g. "Place", "Color", ...
    let title: String
    let description: String
    
    var assetName: String {
        "icon_\(category.lowercased())"
    }
}

final class DailyViewModel: ObservableObject {
    @Published var mantra = ""
    @Published var items: [SuggestionItem] = []
    
    private let db = Firestore.firestore()
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private static func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func load(for date: Date) {
        DispatchQueue.main.async {
            self.mantra = ""
            self.items.removeAll()
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 依然无法获取 UID")
            return
        }
        
        let ds = Self.fmt.string(from: date)
        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: ds)
            .getDocuments { snap, err in
                if let err = err {
                    print("Firestore error:", err); return
                }
                guard let doc = snap?.documents.first else {
                    print("No recommendation for", ds); return
                }
                let data = doc.data()
                self.mantra = data["mantra"] as? String ?? ""
                self.fetchDetails(
                    pairs: [
                        ("Place",        data["Place"] as? String ?? ""),
                        ("Color",        data["Color"] as? String ?? ""),
                        ("Gemstone",     data["Gemstone"] as? String ?? ""),
                        ("Scent",        data["Scent"] as? String ?? ""),
                        ("Activity",     data["Activity"] as? String ?? ""),
                        ("Sound",        data["Sound"] as? String ?? ""),
                        ("Career",       data["Career"] as? String ?? ""),
                        ("Relationship", data["Relationship"] as? String ?? "")
                    ]
                )
            }
    }
    
    private func fetchDetails(pairs: [(String,String)]) {
        let validPairs = pairs.filter { !$0.1.isEmpty }

        DispatchQueue.main.async {
            self.items.removeAll()
        }

        guard !validPairs.isEmpty else { return }

        let orderedCategories = validPairs.map(\.0)
        let lock = NSLock()
        var pendingCount = validPairs.count
        var resultsByCategory: [String: SuggestionItem] = [:]

        func completeRequest() {
            let orderedItems: [SuggestionItem]?

            lock.lock()
            pendingCount -= 1
            if pendingCount == 0 {
                orderedItems = orderedCategories.compactMap { resultsByCategory[$0] }
            } else {
                orderedItems = nil
            }
            lock.unlock()

            guard let orderedItems else { return }
            DispatchQueue.main.async {
                self.items = orderedItems
            }
        }

        for (category, docName) in validPairs {
            let collectionName = category == "Activity"
                ? "activities"
                : category.lowercased() + "s"

            let normalizedDocName = Self.sanitizeDocumentName(docName)

            db.collection(collectionName).document(normalizedDocName)
                .getDocument { snapshot, err in
                    if let err = err {
                        print("⚠️", err)
                        completeRequest()
                        return
                    }
                    guard let snap = snapshot,
                          let data = snap.data() else {
                        print("No data at \(collectionName)/\(normalizedDocName) (raw: \(docName))")
                        completeRequest()
                        return
                    }
                    
                    // build a *guaranteed* unique SwiftUI id
                    let uniqueID = "\(category)-\(snap.documentID)"
                    let title = data["title"] as? String ?? ""
                    let desc  = data["description"] as? String ?? ""
                    
                    let item = SuggestionItem(
                        id: uniqueID,
                        category: category,
                        title: title,
                        description: desc
                    )

                    lock.lock()
                    resultsByCategory[category] = item
                    lock.unlock()
                    completeRequest()
                }
        }
    }
}
