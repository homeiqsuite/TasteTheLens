import SwiftUI

struct SideBySideExportView: View {
    let recipe: Recipe

    private let canvasSize: CGFloat = 1080
    private let bg = Theme.darkBg
    private let gold = Theme.gold

    var body: some View {
        ZStack {
            // Layer 1: Full-bleed dish image (or inspiration fallback)
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(width: canvasSize, height: canvasSize)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
                Color.clear
                    .frame(width: canvasSize, height: canvasSize)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            }

            // Layer 2: Gradient scrim
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 3: Bottom overlay — dish name + branding (left), approach badge (right)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.dishName)
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.darkTextPrimary)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)

                        Text("Taste The Lens")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                    }

                    Spacer()

                    if let analysis = recipe.sceneAnalysis {
                        Text(approachShortLabel(analysis.approach))
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.darkTextPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 56)
            }

            // Layer 4: Top-right PIP thumbnail(s)
            if recipe.isFusion {
                let allImages = recipe.allInspirationImages
                if !allImages.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 10) {
                                HStack(spacing: -24) {
                                    ForEach(Array(allImages.enumerated()), id: \.offset) { index, img in
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 110, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(gold, lineWidth: 3)
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 8)
                                            .zIndex(Double(allImages.count - index))
                                    }
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18))
                                    Text("Fusion")
                                        .font(.system(size: 22, weight: .bold))
                                }
                                .foregroundStyle(gold)
                            }
                            .padding(.trailing, 40)
                            .padding(.top, 40)
                        }
                        Spacer()
                    }
                }
            } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(.white, lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 12)
                            .padding(.trailing, 40)
                            .padding(.top, 40)
                    }
                    Spacer()
                }
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
        .frame(width: canvasSize, height: canvasSize)
        .background(bg)
    }

    private func approachShortLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Ingredient-driven"
        case "hybrid": return "Hybrid"
        default: return "Visual"
        }
    }
}
