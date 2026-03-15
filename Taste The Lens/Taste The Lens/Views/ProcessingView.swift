import SwiftUI

struct ProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline

    // Colors extracted from the source image by the API
    private var displayColors: [String] {
        pipeline.extractedColors.isEmpty ? [] : pipeline.extractedColors
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Frozen captured image (overlay pattern to prevent layout inflation)
                Color.clear
                    .overlay {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .ignoresSafeArea()

                // Dark overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                // Geometric line traces
                GeometricOverlay()
                    .ignoresSafeArea()

                // Content overlay
                VStack {
                    Spacer()

                    // Color swatches pinned to right (shown once extracted from API)
                    if !displayColors.isEmpty {
                        HStack {
                            Spacer()
                            ColorSwatchRow(colors: displayColors)
                                .padding(.trailing, 20)
                        }
                        .transition(.opacity)
                    }

                    Spacer()

                    // Status text
                    StatusText(status: pipeline.processingStatus)
                        .padding(.bottom, 60)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Blur transition when complete
                if pipeline.state == .complete {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: pipeline.state)
        .animation(.easeInOut(duration: 0.4), value: pipeline.extractedColors)
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 50, y: 150, width: 300, height: 300))
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 150, y: 50, width: 100, height: 500))
        }
    }()

    let pipeline: ImageAnalysisPipeline = {
        let p = ImageAnalysisPipeline()
        p.processingStatus = "Extracting palette..."
        p.state = .analyzingImage
        return p
    }()

    ProcessingView(capturedImage: sampleImage, pipeline: pipeline)
}
