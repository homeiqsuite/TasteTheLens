import SwiftUI

struct FusionTrayView: View {
    let images: [UIImage]
    let onRemove: (Int) -> Void
    let onFuse: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Film strip — always 3 slots
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    if index < images.count {
                        filledSlot(index: index, image: images[index])
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        emptySlot
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: images.count)

            // Fuse button
            if images.count >= 2 {
                Button {
                    HapticManager.medium()
                    onFuse()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Fuse")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Theme.darkBg)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.ctaGradient, in: Capsule())
                    .shadow(color: Theme.gold.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    // MARK: - Slots

    private func filledSlot(index: Int, image: UIImage) -> some View {
        Color.clear
            .frame(width: 48, height: 48)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Theme.gold, lineWidth: 2)
            )
            .onTapGesture {
                HapticManager.light()
                onRemove(index)
            }
    }

    private var emptySlot: some View {
        Circle()
            .strokeBorder(Theme.darkTextHint.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: 48, height: 48)
    }
}
