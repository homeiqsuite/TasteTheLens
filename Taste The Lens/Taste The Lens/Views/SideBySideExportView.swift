import SwiftUI

struct SideBySideExportView: View {
    let recipe: Recipe

    private let canvasSize: CGFloat = 1080
    private let bottomBarHeight: CGFloat = 80
    private let bg = Theme.darkBg
    private let gold = Theme.gold

    private var photoHeight: CGFloat { canvasSize - bottomBarHeight }
    private var photoWidth: CGFloat { (canvasSize - 2) / 2 } // 2pt divider

    var body: some View {
        VStack(spacing: 0) {
            // Photos side by side
            HStack(spacing: 0) {
                // Left: inspiration photo
                if let uiImage = UIImage(data: recipe.inspirationImageData) {
                    Color.clear
                        .frame(width: photoWidth, height: photoHeight)
                        .overlay {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipped()
                } else {
                    bg.frame(width: photoWidth, height: photoHeight)
                }

                // Thin white divider
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: photoHeight)

                // Right: generated dish
                if let imageData = recipe.generatedDishImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: photoWidth, height: photoHeight)
                        .background(bg)
                } else {
                    bg.frame(width: photoWidth, height: photoHeight)
                }
            }

            // Watermark overlay for non-subscribers
            if EntitlementManager.shared.requiresUpgrade(for: .cleanExport) {
                Text("TASTE THE LENS")
                    .font(.system(size: 72, weight: .bold, design: .default))
                    .foregroundStyle(.white.opacity(0.2))
                    .rotationEffect(.degrees(-30))
                    .allowsHitTesting(false)
            }

            // Bottom bar
            HStack {
                Text(recipe.dishName)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .lineLimit(1)

                Spacer()

                Text("Taste The Lens")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Theme.darkTextSecondary)
            }
            .padding(.horizontal, 24)
            .frame(height: bottomBarHeight)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.7))
        }
        .frame(width: canvasSize, height: canvasSize)
        .background(bg)
    }
}
