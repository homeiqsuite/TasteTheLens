import SwiftUI

struct ProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline
    var onCancel: (() -> Void)?
    var additionalImages: [UIImage] = []

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
                    // Cancel button (top-left)
                    HStack {
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.darkTextSecondary)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        Spacer()
                    }

                    // Fusion badge
                    if !additionalImages.isEmpty {
                        FusionBadgeView(images: [capturedImage] + additionalImages)
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Progress steps
                    ProgressStepsView(state: pipeline.state)
                        .padding(.horizontal, 40)

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

                    // Status text + timeout warning
                    VStack(spacing: 12) {
                        StatusText(status: pipeline.processingStatus)

                        if let startTime = pipeline.startTime {
                            TimeoutWarningView(startTime: startTime, onCancel: onCancel)
                        }
                    }
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

// MARK: - Progress Steps

struct ProgressStepsView: View {
    let state: PipelineState

    private let gold = Theme.gold

    private var currentStep: Int {
        switch state {
        case .screeningImage: return 0
        case .analyzingImage: return 1
        case .generatingImage: return 2
        case .complete: return 3
        default: return -1
        }
    }

    private let steps = ["Screening", "Analyzing", "Generating"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 6) {
                    stepIndicator(for: index)
                    Text(label)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor(for: index))
                }

                if index < steps.count - 1 {
                    Spacer()
                    Rectangle()
                        .fill(index < currentStep ? gold.opacity(0.4) : Theme.darkStroke)
                        .frame(height: 1)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func stepIndicator(for index: Int) -> some View {
        if index < currentStep {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(gold)
        } else if index == currentStep {
            PulsingDot()
        } else {
            Circle()
                .fill(Theme.darkTextHint)
                .frame(width: 10, height: 10)
        }
    }

    private func textColor(for index: Int) -> Color {
        if index < currentStep {
            return gold.opacity(0.8)
        } else if index == currentStep {
            return Theme.darkTextSecondary
        } else {
            return Theme.darkTextHint
        }
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Timeout Warning

struct TimeoutWarningView: View {
    let startTime: Date
    var onCancel: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = Int(timeline.date.timeIntervalSince(startTime))
            Group {
                if elapsed >= 90 {
                    VStack(spacing: 8) {
                        Text("Still working. You can cancel and try again.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                        Button {
                            onCancel?()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.darkTextPrimary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Theme.darkTextHint)
                                .clipShape(Capsule())
                        }
                    }
                } else if elapsed >= 45 {
                    Text("Taking longer than usual...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.darkTextTertiary)
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
        p.startTime = Date()
        return p
    }()

    ProcessingView(capturedImage: sampleImage, pipeline: pipeline, onCancel: {})
}
