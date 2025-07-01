import SwiftUI
import FirebaseFirestore

struct RecommendationItem: Codable {
    var name: String
    var title: String
    var description: String
    var explanation: String
}

struct RecommendationDetailView: View {
    let category: String
    let documentName: String
    @State private var item: RecommendationItem?

    var body: some View {
        VStack(spacing: 20) {
            if let item = item {
                Text(item.title)
                    .font(.title)
                Text(item.description)
                    .font(.body)
                Text(item.explanation)
                    .font(.footnote)
                    .padding(.horizontal)
            } else {
                ProgressView("Loading...")
            }
        }
        .padding()
        .onAppear {
            fetchItem()
        }
    }

    private func fetchItem() {
        let db = Firestore.firestore()
        db.collection(category).document(documentName).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取 Firebase 数据失败: \(error)")
                return
            }
            do {
                if let data = try snapshot?.data(as: RecommendationItem.self) {
                    self.item = data
                } else {
                    print("❌ 文档未找到或解码失败")
                }
            } catch {
                print("❌ 解码失败: \(error)")
            }
        }
    }
}
