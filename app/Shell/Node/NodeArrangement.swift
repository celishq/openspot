import OpenspotCore
import SwiftUI

struct NodeArrangement: Layout {
    let style: Style
    var outset: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = placement(ProposedViewSize(bounds.size), subviews)
        for (subview, frame) in zip(subviews, placed.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func placement(_ proposal: ProposedViewSize, _ subviews: Subviews) -> BoxLayout.Placement {
        let children = subviews.map { subview in
            BoxLayout.Child(style: subview[NodeSlot.self]) { width, height in
                subview.sizeThatFits(ProposedViewSize(width: width, height: height))
            }
        }
        return BoxLayout(style: style, outset: outset).place(children, width: Self.finite(proposal.width), height: Self.finite(proposal.height))
    }

    private static func finite(_ length: CGFloat?) -> CGFloat? {
        length.flatMap { $0.isFinite ? $0 : nil }
    }
}
