import SwiftUI

struct MiseEnPlaceProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline
    var onCancel: (() -> Void)?

    @State private var scanLineOffset: CGFloat = 0
    @State private var showDishName = false
    @State private var visibleIngredientCount = 0
    @State private var blurRadius: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Ken Burns background
                Color.clear
                    .overlay {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .kenBurns()
                    }
                    .clipped()
                    .ignoresSafeArea()

                // Dark gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Scanning line during screening
                if pipeline.state == .screeningImage {
                    scanLine(height: geo.size.height)
                }

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

                    // Progressive reveal area
                    VStack(spacing: 20) {
                        // Dish name — large serif typography
                        if let dishName = pipeline.partialDishName, showDishName {
                            Text(dishName)
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.darkTextPrimary)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .padding(.horizontal, 32)
                        }

                        // Floating ingredients
                        if visibleIngredientCount > 0 {
                            VStack(spacing: 10) {
                                ForEach(
                                    Array(pipeline.partialIngredients.prefix(min(visibleIngredientCount, 8)).enumerated()),
                                    id: \.offset
                                ) { _, ingredient in
                                    Text(ingredient)
                                        .font(.system(size: 16, weight: .medium, design: .serif))
                                        .foregroundStyle(Theme.gold.opacity(0.9))
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        }

                        // De-blur placeholder during generation
                        if pipeline.state == .generatingImage {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.darkSurface)
                                .frame(width: 200, height: 140)
                                .blur(radius: blurRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.gold.opacity(0.2), lineWidth: 1)
                                )
                                .transition(.opacity)
                        }
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
        .onChange(of: pipeline.state) { _, newState in
            if newState == .generatingImage {
                // Dish name reveal
                withAnimation(.easeOut(duration: 0.8)) {
                    showDishName = true
                }
                // Stagger ingredients
                revealIngredients()
                // Progressive de-blur
                withAnimation(.easeInOut(duration: 6)) {
                    blurRadius = 2
                }
            }
        }
    }

    // MARK: - Scan Line

    private func scanLine(height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Theme.visual.opacity(0), Theme.visual.opacity(0.4), Theme.visual.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .offset(y: scanLineOffset)
            .onAppear {
                scanLineOffset = -height / 2
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    scanLineOffset = height / 2
                }
            }
    }

    // MARK: - Ingredient Reveal

    private func revealIngredients() {
        let total = min(pipeline.partialIngredients.count, 8)
        for i in 1...max(total, 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    visibleIngredientCount = i
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 50, y: 100, width: 300, height: 400))
        }
    }()

    let pipeline: ImageAnalysisPipeline = {
        let p = ImageAnalysisPipeline()
        p.state = .generatingImage
        p.processingStatus = "Plating concept..."
        p.startTime = Date()
        p.partialDishName = "Saffron-Kissed Sunset Risotto"
        p.partialIngredients = ["Arborio Rice", "Saffron Threads", "White Wine", "Parmesan", "Shallots"]
        return p
    }()

    MiseEnPlaceProcessingView(capturedImage: sampleImage, pipeline: pipeline, onCancel: {})
}
