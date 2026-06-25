import SwiftUI

/// Full-bleed hero backdrop for the Recipe Detail view. Renders the generated
/// dish photo (or the inspiration photo as a fallback) behind the content card.
struct HeroBackdropView: View {
    let recipe: Recipe
    var height: CGFloat = 360
    var onImageTap: ((Int) -> Void)? = nil

    private var hasGeneratedImage: Bool {
        recipe.generatedDishImageData != nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            heroImage
            topScrim
            if !hasGeneratedImage {
                inspirationLabel
            }
            sourcePIPs
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageData = recipe.generatedDishImageData,
           let uiImage = UIImage(data: imageData) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
        } else if let uiImage = UIImage(data: recipe.inspirationImageData) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
                .overlay(Theme.visual.opacity(0.25))
        } else {
            Theme.darkBg
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }

    /// Subtle dark scrim at the top so the floating controls stay legible
    /// regardless of the underlying image.
    private var topScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.3), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .allowsHitTesting(false)
    }

    private var inspirationLabel: some View {
        HStack {
            Label("Showing your inspiration photo", systemImage: "photo")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 120)
    }

    @ViewBuilder
    private var sourcePIPs: some View {
        if recipe.isFusion {
            let allImages = recipe.allInspirationImages
            if !allImages.isEmpty {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: -8) {
                            ForEach(Array(allImages.enumerated()), id: \.offset) { index, img in
                                Button {
                                    HapticManager.light()
                                    onImageTap?(index)
                                } label: {
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
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Inspiration photo \(index + 1)")
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 104)
            }
        } else if hasGeneratedImage, let uiImage = UIImage(data: recipe.inspirationImageData) {
            HStack {
                Spacer()
                Button {
                    HapticManager.light()
                    onImageTap?(0)
                } label: {
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View inspiration photo")
            }
            .padding(.horizontal, 16)
            .padding(.top, 104)
        }
    }
}
