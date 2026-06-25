import SwiftUI

/// Fullscreen viewer for the user's inspiration photo(s). Supports swiping
/// between fusion images and pinch-to-zoom on each page. Mirrors the
/// interaction style of `FullscreenPhotoView` in `ChallengeDetailView`, but
/// works with local `UIImage` data instead of a remote URL.
struct InspirationImageViewer: View {
    let images: [UIImage]
    var startIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(images: [UIImage], startIndex: Int = 0) {
        self.images = images
        self.startIndex = startIndex
        let safeStart = max(0, min(startIndex, max(0, images.count - 1)))
        _selectedIndex = State(initialValue: safeStart)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if images.isEmpty {
                Text("No image")
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZoomableImagePage(image: image) {
                            dismiss()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(16)
            }
            .accessibilityLabel("Close photo viewer")

            // Photo counter
            if images.count > 1 {
                VStack {
                    Spacer()
                    Text("Photo \(selectedIndex + 1) of \(images.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - Zoomable Page

private struct ZoomableImagePage: View {
    let image: UIImage
    let onSingleTapDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1.0, lastScale * value)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.0 {
                            withAnimation(.spring()) { scale = 1.0 }
                            lastScale = 1.0
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
            .onTapGesture(count: 1) {
                if scale <= 1.0 {
                    onSingleTapDismiss()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let sample: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        return renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 100, y: 200, width: 400, height: 400))
        }
    }()
    return InspirationImageViewer(images: [sample, sample, sample], startIndex: 1)
}
