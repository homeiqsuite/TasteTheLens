import SwiftUI

struct CompactHeroView: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed generated dish image (or inspiration fallback)
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .overlay(Theme.visual.opacity(0.35))
                    .overlay(alignment: .topLeading) {
                        Label("Showing your inspiration photo", systemImage: "photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(10)
                    }
            }

            // Gradient scrim
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)

            // Overlay content
            HStack(alignment: .bottom) {
                Text(recipe.dishName)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Spacer()

                if let analysis = recipe.sceneAnalysis {
                    Text(approachShortLabel(analysis.approach))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Source PIP thumbnail(s) (top-right)
            if recipe.isFusion {
                let allImages = recipe.allInspirationImages
                if !allImages.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                HStack(spacing: -8) {
                                    ForEach(Array(allImages.enumerated()), id: \.offset) { index, img in
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 36, height: 36)
                                            .clipShape(RoundedRectangle(cornerRadius: 7))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 7)
                                                    .stroke(Theme.gold, lineWidth: 1.5)
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 3)
                                            .zIndex(Double(allImages.count - index))
                                    }
                                }
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 7))
                                    Text("Fusion")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(Theme.gold)
                            }
                            .padding(.trailing, 12)
                            .padding(.top, 12)
                        }
                        Spacer()
                    }
                    .frame(height: 220)
                }
            } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .padding(.trailing, 12)
                            .padding(.top, 12)
                    }
                    Spacer()
                }
                .frame(height: 220)
            }
        }
    }

    private func approachShortLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Ingredient-driven"
        case "hybrid": return "Hybrid"
        default: return "Visual"
        }
    }
}
