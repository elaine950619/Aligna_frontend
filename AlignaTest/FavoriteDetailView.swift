import SwiftUI
import UIKit

struct FavoriteDetailView: View {
    let snapshot: MantraSnapshot
    let itemId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager
    @StateObject private var store = FavoritesStore.shared

    @State private var isDeleting: Bool = false

    private let cardWidth:  CGFloat = 390
    private let cardHeight: CGFloat = 693

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Scaled preview of the exact ShareCardRenderView.
                    GeometryReader { geo in
                        let scale = min((geo.size.width - 32) / cardWidth,
                                        (geo.size.height) / cardHeight)
                        let displayW = cardWidth * scale
                        let displayH = cardHeight * scale
                        ZStack {
                            ShareCardRenderView(snapshot: snapshot)
                                .frame(width: cardWidth, height: cardHeight)
                                .scaleEffect(scale)
                                .frame(width: displayW, height: displayH)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color.black.opacity(0.25), radius: 22, x: 0, y: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: cardHeight * 0.78)
                    .padding(.top, 10)

                    // Action row
                    HStack(spacing: 14) {
                        Button { shareCard() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                Text("main.share")
                                    .font(.custom("Merriweather-Regular", size: 15))
                            }
                            .foregroundColor(themeManager.primaryText)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(themeManager.panelFill.opacity(0.38))
                            .clipShape(Capsule())
                        }
                        Button { handleDelete() } label: {
                            HStack(spacing: 6) {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.75)
                                        .tint(themeManager.primaryText)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Text("favorites.delete")
                                    .font(.custom("Merriweather-Regular", size: 15))
                            }
                            .foregroundColor(themeManager.primaryText.opacity(0.80))
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(themeManager.panelFill.opacity(0.22))
                            .clipShape(Capsule())
                        }
                        .disabled(isDeleting)
                    }
                    .padding(.vertical, 6)
                }
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(Text(formattedTitle()))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func handleDelete() {
        isDeleting = true
        Task { @MainActor in
            let removed = await store.delete(id: itemId)
            isDeleting = false
            if removed != nil {
                dismiss()
            }
        }
    }

    private func shareCard() {
        FontRegistrar.registerAllFonts()
        let renderSize = CGSize(width: cardWidth, height: cardHeight)
        let renderView = ShareCardRenderView(snapshot: snapshot)
        let controller = UIHostingController(rootView: renderView)
        controller.safeAreaRegions = []
        controller.view.bounds = CGRect(origin: .zero, size: renderSize)
        controller.view.frame  = CGRect(origin: .zero, size: renderSize)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        var presenter: UIViewController = root
        while let next = presenter.presentedViewController { presenter = next }

        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                       y: presenter.view.bounds.maxY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }

    private func formattedTitle() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: snapshot.localeCode)
        df.setLocalizedDateFormatFromTemplate("yMMMd")
        return df.string(from: snapshot.date)
    }
}
