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
        items.removeAll()
        for (category, docName) in pairs where !docName.isEmpty {
            var colName = category.lowercased() + "s"   // “places”, “colors”, …
            if colName == "activitys" {
                colName = "activities"
            }
            
            db.collection(colName).document(docName)
                .getDocument { snapshot, err in
                    if let err = err {
                        print("⚠️", err); return
                    }
                    guard let snap = snapshot,
                          let data = snap.data() else {
                        print("No data at \(colName)/\(docName)"); return
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
                    DispatchQueue.main.async {
                        self.items.append(item)
                    }
                }
        }
    }
}


