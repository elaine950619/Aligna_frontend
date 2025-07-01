import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            Color(hex: "#E6D9BD")
                .ignoresSafeArea()
            Text("This is the About page.")
                .foregroundColor(.black)
                .font(.title2)
        }
        .navigationTitle("About")
    }
}
