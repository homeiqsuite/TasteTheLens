import SwiftUI

struct SideBySideExportView: View {
    let recipe: Recipe

    private let canvasSize: CGFloat = 1080
    private let bottomBarHeight: CGFloat = 80
    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

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

            // Bottom bar
            HStack {
                Text(recipe.dishName)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text("Taste The Lens")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.6))
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
