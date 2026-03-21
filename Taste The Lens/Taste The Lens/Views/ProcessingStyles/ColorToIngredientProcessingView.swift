import SwiftUI

struct ColorToIngredientProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline
    var onCancel: (() -> Void)?

    @State private var localColors: [String] = []
    @State private var appeared = false
    @State private var morphed = false

    private var ingredients: [String] {
        pipeline.partialIngredients
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Static background image
                Color.clear
                    .overlay {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .ignoresSafeArea()

                // Dark overlay
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Content
                VStack {
                    // Cancel button
                    HStack {
                        ProcessingCancelButton(onCancel: onCancel)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        Spacer()
                    }

                    Spacer()

                    // Color swatches / ingredient morphing
                    if !localColors.isEmpty {
                        VStack(spacing: 16) {
                            Text(morphed ? "INGREDIENTS FOUND" : "PALETTE EXTRACTED")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.darkTextTertiary)
                                .tracking(1.5)
                                .animation(.easeInOut(duration: 0.3), value: morphed)

                            ForEach(Array(localColors.enumerated()), id: \.offset) { index, hex in
                                colorSwatchRow(index: index, hex: hex)
                            }
                        }
                        .padding(.horizontal, 32)
                    }

                    Spacer()

                    // Status + timeout
                    VStack(spacing: 12) {
                        StatusText(status: pipeline.processingStatus)

                        if let startTime = pipeline.startTime {
                            TimeoutWarningView(startTime: startTime, onCancel: onCancel)
                        }
                    }
                    .padding(.bottom, 60)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Complete overlay
                if pipeline.state == .complete {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: pipeline.state)
        .onAppear {
            localColors = DominantColorExtractor.extractColors(from: capturedImage)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                appeared = true
            }
        }
        .onChange(of: pipeline.state) { _, newState in
            if newState == .generatingImage && !ingredients.isEmpty {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    morphed = true
                }
            }
        }
    }

    // MARK: - Color Swatch Row

    private func colorSwatchRow(index: Int, hex: String) -> some View {
        let ingredientName = index < ingredients.count ? ingredients[index] : nil
        let showIngredient = morphed && ingredientName != nil
        let staggerDelay = Double(index) * 0.15

        return HStack(spacing: 14) {
            // Color circle
            Circle()
                .fill(Color(hex: hex))
                .frame(width: showIngredient ? 28 : 36, height: showIngredient ? 28 : 36)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(hex: hex).opacity(0.4), radius: 6)

            if showIngredient {
                // Ingredient name
                Text(ingredientName!)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                // Hex label
                Text(hex)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .transition(.opacity)
            }

            Spacer()

            // Arrow indicator when morphing
            if showIngredient {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.visual.opacity(0.6))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(showIngredient ? Theme.culinary.opacity(0.1) : Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    showIngredient ? Theme.culinary.opacity(0.3) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
        .offset(x: appeared ? 0 : 120)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8).delay(staggerDelay),
            value: appeared
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(staggerDelay), value: morphed)
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        return renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 200, y: 0, width: 200, height: 300))
            UIColor.systemBrown.setFill()
            ctx.fill(CGRect(x: 0, y: 300, width: 200, height: 300))
            UIColor.systemRed.setFill()
            ctx.fill(CGRect(x: 200, y: 300, width: 200, height: 300))
        }
    }()

    let pipeline: ImageAnalysisPipeline = {
        let p = ImageAnalysisPipeline()
        p.state = .generatingImage
        p.processingStatus = "Plating concept..."
        p.startTime = Date()
        p.partialIngredients = ["Roasted Carrots", "Fresh Basil", "Cocoa Nibs", "Cherry Tomatoes"]
        return p
    }()

    ColorToIngredientProcessingView(capturedImage: sampleImage, pipeline: pipeline, onCancel: {})
}
