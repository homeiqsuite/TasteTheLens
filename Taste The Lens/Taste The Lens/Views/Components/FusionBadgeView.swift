import SwiftUI

/// Shows a "Fusion" pill badge with source image thumbnails.
/// Used in processing views when multiple images were captured.
struct FusionBadgeView: View {
    let images: [UIImage]

    var body: some View {
        HStack(spacing: 10) {
            // Source thumbnails
            HStack(spacing: -8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Color.clear
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Theme.gold, lineWidth: 1.5)
                        )
                        .zIndex(Double(images.count - index))
                }
            }

            // Label
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                Text("Fusion")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
        )
    }
}
