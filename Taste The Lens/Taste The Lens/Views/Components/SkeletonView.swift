import SwiftUI

/// A shimmering skeleton placeholder for loading states.
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.divider)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
    }
}

/// A skeleton card that mimics a recipe card shape during loading.
struct SkeletonRecipeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(height: 140, cornerRadius: 12)
            SkeletonView(width: 120, height: 14)
            SkeletonView(width: 80, height: 10)
        }
        .lightCard(cornerRadius: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        SkeletonView(height: 200, cornerRadius: 16)
        HStack {
            SkeletonRecipeCard()
            SkeletonRecipeCard()
        }
    }
    .padding()
    .background(Theme.background)
}
