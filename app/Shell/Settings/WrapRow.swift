import SwiftUI

struct WrapRow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let places = places(of: subviews, width: proposal.width ?? .infinity)
        return CGSize(width: places.map(\.maxX).max() ?? 0, height: places.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, place) in zip(subviews, places(of: subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX + place.minX, y: bounds.minY + place.minY), proposal: ProposedViewSize(place.size))
        }
    }

    private func places(of subviews: Subviews, width: CGFloat) -> [CGRect] {
        var places: [CGRect] = []
        var point = CGPoint.zero
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > 0, point.x + size.width > width {
                point = CGPoint(x: 0, y: point.y + lineHeight + spacing)
                lineHeight = 0
            }
            places.append(CGRect(origin: point, size: size))
            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return places
    }
}
