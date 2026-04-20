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
    @Published var actions: [DailyAction] = []
    @Published var completedActionIDs: Set<String> = []

    private let db = Firestore.firestore()
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private static func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Local fallback recommendations (mirrors FirstPageView.DesignRecs)
    private static let fallbackDocs: [String: String] = [
        "Place": "echo_niche",
        "Gemstone": "amethyst",
        "Color": "amber",
        "Scent": "bergamot",
        "Activity": "clean_mirror",
        "Sound": "brown_noise",
        "Career": "clear_channel",
        "Relationship": "breathe_sync",
    ]

    private static let fallbackMantra = "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."

    func load(for date: Date) {
        DispatchQueue.main.async {
            self.mantra = ""
            self.items.removeAll()
            self.actions.removeAll()
            self.completedActionIDs.removeAll()
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 依然无法获取 UID")
            return
        }

        let ds = Self.fmt.string(from: date)
        print("📅 [CAL_REC_FETCH] uid=\(userId) day=\(ds) (query by uid+createdAt)")

        var didRetry = false

        func fallbackToDesignRecs(reason: String) {
            print("🌱 [CAL_REC_FALLBACK] uid=\(userId) day=\(ds) reason=\(reason)")
            self.mantra = Self.fallbackMantra

            let pairs: [(String, String)] = [
                ("Place",        Self.fallbackDocs["Place"] ?? ""),
                ("Color",        Self.fallbackDocs["Color"] ?? ""),
                ("Gemstone",     Self.fallbackDocs["Gemstone"] ?? ""),
                ("Scent",        Self.fallbackDocs["Scent"] ?? ""),
                ("Activity",     Self.fallbackDocs["Activity"] ?? ""),
                ("Sound",        Self.fallbackDocs["Sound"] ?? ""),
                ("Career",       Self.fallbackDocs["Career"] ?? ""),
                ("Relationship", Self.fallbackDocs["Relationship"] ?? ""),
            ]
            self.fetchDetails(pairs: pairs)
        }

        func applyDoc(_ doc: DocumentSnapshot, source: String) {
            let data = doc.data() ?? [:]
            let keys = Array(data.keys)
            print("📄 [CAL_REC_DOC] source=\(source) uid=\(userId) day=\(ds) docId=\(doc.documentID) keys=\(keys)")

            let pairs: [(String, String)] = [
                ("Place",        data["Place"] as? String ?? ""),
                ("Color",        data["Color"] as? String ?? ""),
                ("Gemstone",     data["Gemstone"] as? String ?? ""),
                ("Scent",        data["Scent"] as? String ?? ""),
                ("Activity",     data["Activity"] as? String ?? ""),
                ("Sound",        data["Sound"] as? String ?? ""),
                ("Career",       data["Career"] as? String ?? ""),
                ("Relationship", data["Relationship"] as? String ?? ""),
            ]

            let nonEmpty = pairs.filter { !$0.1.isEmpty }
            if nonEmpty.isEmpty {
                print("⚠️ [CAL_REC_DECODE_EMPTY] uid=\(userId) day=\(ds) docId=\(doc.documentID) — no category fields present; falling back")
                fallbackToDesignRecs(reason: "decode_empty")
                return
            }

            self.mantra = data["mantra"] as? String ?? ""
            self.fetchDetails(pairs: nonEmpty)

            // Read daily actions and completed IDs
            if let rawActions = data["daily_actions"] as? [[String: Any]] {
                let parsedActions = rawActions.compactMap { dict -> DailyAction? in
                    guard
                        let id  = dict["id"]            as? String, !id.isEmpty,
                        let cat = dict["category"]      as? String,
                        let doc = dict["document_name"] as? String,
                        let eng = dict["how_to_engage"] as? String
                    else { return nil }
                    return DailyAction(id: id, category: cat, documentName: doc, howToEngage: eng)
                }
                let completedIDs = Set((data["completed_action_ids"] as? [String]) ?? [])
                DispatchQueue.main.async {
                    self.actions = parsedActions
                    self.completedActionIDs = completedIDs
                }
            }
        }

        func retryByFixedDocId(reason: String) {
            if didRetry {
                fallbackToDesignRecs(reason: "retry_exhausted_\(reason)")
                return
            }
            didRetry = true

            let fixedId = "\(userId)_\(ds)"
            let fixedRef = db.collection("daily_recommendation").document(fixedId)
            print("🔁 [CAL_REC_RETRY] uid=\(userId) day=\(ds) docId=\(fixedId) reason=\(reason)")

            fixedRef.getDocument { snap2, err2 in
                if let err2 = err2 {
                    print("❌ [CAL_REC_RETRY_ERR] uid=\(userId) day=\(ds) error=\(err2)")
                    fallbackToDesignRecs(reason: "retry_error")
                    return
                }
                guard let doc2 = snap2, doc2.exists else {
                    print("⚠️ [CAL_REC_RETRY_NOT_FOUND] uid=\(userId) day=\(ds) docId=\(fixedId)")
                    fallbackToDesignRecs(reason: "retry_not_found")
                    return
                }
                applyDoc(doc2, source: "docId")
            }
        }

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: ds)
            .getDocuments { snap, err in
                if let err = err {
                    print("❌ [CAL_REC_ERR] uid=\(userId) day=\(ds) error=", err)
                    retryByFixedDocId(reason: "query_error")
                    return
                }
                guard let doc = snap?.documents.first else {
                    print("⚠️ [CAL_REC_MISSING] uid=\(userId) day=\(ds) — no recommendation via query")
                    retryByFixedDocId(reason: "query_empty")
                    return
                }
                applyDoc(doc, source: "query")
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
                    let isChinese = currentRecommendationLanguageCode() == "zh-Hans"
                    let rawTitle = data["title"] as? String ?? ""
                    let rawDesc  = data["description"] as? String ?? ""
                    let titleZh  = data["title_zh"] as? String ?? ""
                    let descZh   = data["description_zh"] as? String ?? ""
                    let title = isChinese && !titleZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? titleZh.trimmingCharacters(in: .whitespacesAndNewlines)
                        : rawTitle
                    let desc = isChinese && !descZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? descZh.trimmingCharacters(in: .whitespacesAndNewlines)
                        : rawDesc

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
