import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        let maxWidth = proposal.width ?? .infinity
        for (index, position) in result.positions.enumerated() {
            let itemWidth = min(subviews[index].sizeThatFits(.unspecified).width, maxWidth)
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(width: itemWidth, height: nil)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let clampedWidth = min(size.width, maxWidth)
            if currentX + clampedWidth > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            let clampedSize = subview.sizeThatFits(ProposedViewSize(width: clampedWidth, height: nil))
            lineHeight = max(lineHeight, clampedSize.height)
            currentX += clampedWidth + spacing
            totalHeight = currentY + lineHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}
