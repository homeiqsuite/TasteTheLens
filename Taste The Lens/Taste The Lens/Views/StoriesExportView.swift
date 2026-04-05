import SwiftUI

struct StoriesExportView: View {
    let recipe: Recipe

    private let canvasWidth: CGFloat = 1080
    private let canvasHeight: CGFloat = 1920
    private let gold = Theme.gold

    var body: some View {
        ZStack {
            // Layer 1: Full-bleed dish image
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(width: canvasWidth, height: canvasHeight)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
                Color.clear
                    .frame(width: canvasWidth, height: canvasHeight)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            }

            // Layer 2: Heavy bottom gradient scrim
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 3: Top-right inspiration PIP
            VStack {
                HStack {
                    Spacer()
                    if let uiImage = UIImage(data: recipe.inspirationImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(.white, lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 16)
                            .padding(.trailing, 48)
                            .padding(.top, 80)
                    }
                }
                Spacer()
            }

            // Layer 4: Bottom content — dish name + branding
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    Text(recipe.dishName)
                        .font(.system(size: 80, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24))
                            .foregroundStyle(gold)
                        Text("Taste The Lens")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(gold)
                    }
                }
                .padding(.horizontal, 64)
                .padding(.bottom, 120)
            }

            // Layer 5: Watermark for non-subscribers
            if EntitlementManager.shared.requiresUpgrade(for: .cleanExport) {
                Text("TASTE THE LENS")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-30))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(Theme.darkBg)
    }
}
