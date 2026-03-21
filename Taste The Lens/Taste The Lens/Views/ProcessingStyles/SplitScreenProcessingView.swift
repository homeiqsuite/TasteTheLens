import SwiftUI

struct SplitScreenProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline
    var onCancel: (() -> Void)?

    @State private var localColors: [String] = []
    @State private var colorBarsAppeared = false
    @State private var showText = false
    @State private var textSlidUp = false

    private var currentPhase: Int {
        switch pipeline.state {
        case .screeningImage: 1
        case .analyzingImage: 2
        case .generatingImage: 3
        case .complete: 4
        default: 0
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                // Split layout
                HStack(spacing: 0) {
                    // Left half — captured image
                    Color.clear
                        .overlay {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipped()
                        .overlay(
                            // Subtle dark gradient at edges
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Gold divider
                    Rectangle()
                        .fill(Theme.gold.opacity(0.6))
                        .frame(width: 1)

                    // Right half — progressive reveal
                    rightPanel(width: geo.size.width / 2, height: geo.size.height)
                }
                .ignoresSafeArea()

                // Cancel button overlay (top-left)
                VStack {
                    HStack {
                        ProcessingCancelButton(onCancel: onCancel)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()

                    // Status + timeout (full width at bottom)
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
        }
        .onChange(of: pipeline.state) { _, newState in
            switch newState {
            case .screeningImage:
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                    colorBarsAppeared = true
                }
            case .analyzingImage:
                withAnimation(.easeInOut(duration: 0.5)) {
                    showText = true
                }
            case .generatingImage:
                withAnimation(.easeInOut(duration: 0.5)) {
                    textSlidUp = true
                }
            default:
                break
            }
        }
    }

    // MARK: - Right Panel

    private func rightPanel(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Theme.darkBg

            VStack(spacing: 0) {
                // Color bars section
                if colorBarsAppeared {
                    colorBarsView(width: width)
                        .frame(height: showText ? 80 : height * 0.6)
                        .animation(.easeInOut(duration: 0.5), value: showText)
                }

                // Recipe info section
                if showText {
                    recipeInfoView(width: width)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Placeholder for generated image
                if textSlidUp {
                    generationPlaceholder(width: width)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: width)
    }

    // MARK: - Color Bars

    private func colorBarsView(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(localColors.enumerated()), id: \.offset) { index, hex in
                Rectangle()
                    .fill(Color(hex: hex))
                    .overlay(
                        // Hex label when bars are tall
                        VStack {
                            Spacer()
                            if !showText {
                                Text(hex)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .rotationEffect(.degrees(-90))
                                    .padding(.bottom, 12)
                                    .transition(.opacity)
                            }
                        }
                    )
                    .offset(x: colorBarsAppeared ? 0 : width)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1),
                        value: colorBarsAppeared
                    )
            }
        }
        .clipShape(Rectangle())
    }

    // MARK: - Recipe Info

    private func recipeInfoView(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Divider
            Rectangle()
                .fill(Theme.gold.opacity(0.3))
                .frame(height: 1)

            if let dishName = pipeline.partialDishName {
                Text(dishName)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .lineLimit(3)
                    .offset(y: textSlidUp ? -8 : 0)
                    .animation(.easeInOut(duration: 0.4), value: textSlidUp)
            }

            // Ingredient chips
            if !pipeline.partialIngredients.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(pipeline.partialIngredients.prefix(6).enumerated()), id: \.offset) { _, ingredient in
                        Text(ingredient)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.darkSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Theme.darkStroke, lineWidth: 0.5)
                            )
                    }
                }
                .offset(y: textSlidUp ? -8 : 0)
                .animation(.easeInOut(duration: 0.4).delay(0.1), value: textSlidUp)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Generation Placeholder

    private func generationPlaceholder(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Theme.gold.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 14)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.darkSurface)

                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.gold.opacity(0.4))

                    PulsingDot()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(height: 120)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
            UIColor.systemPurple.setFill()
            ctx.fill(CGRect(x: 0, y: 200, width: 400, height: 200))
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 400, width: 400, height: 200))
        }
    }()

    let pipeline: ImageAnalysisPipeline = {
        let p = ImageAnalysisPipeline()
        p.state = .generatingImage
        p.processingStatus = "Plating concept..."
        p.startTime = Date()
        p.partialDishName = "Violet Horizon Tartare"
        p.partialIngredients = ["Beetroot", "Lavender", "Blueberry Gastrique", "Crème Fraîche"]
        return p
    }()

    SplitScreenProcessingView(capturedImage: sampleImage, pipeline: pipeline, onCancel: {})
}
