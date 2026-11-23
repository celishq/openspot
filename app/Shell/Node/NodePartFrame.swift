import OpenspotCore
import SwiftUI

struct NodePartFrame<Content: View>: View {
    let node: ViewNode
    let part: SpotPart
    let look: SpotPart.Look?
    var hasLabel = false
    @ViewBuilder let content: (CGSize) -> Content
    @Environment(\.spotNode) private var context
    @Environment(\.spotSurfaceEdge) private var surface

    var body: some View {
        if context.isCard {
            content(node.naturalSize)
        } else {
            sheet
        }
    }

    private var sheet: some View {
        let natural = node.naturalSize
        let height = natural.height
        let ring = FocusRing(part: part, look: look, hasLabel: hasLabel, surface: surface)
        let hugs = part.isFocusable && ring.hugsControl
        return Group {
            if hasLabel {
                content(natural)
            } else if part.fillsHeight {
                GeometryReader { room in
                    content(room.size).modifier(PartRing(id: part.id, host: context.host, ring: ring, isShown: hugs))
                }
                .frame(minHeight: height, idealHeight: height)
                .frame(idealWidth: natural.width)
            } else {
                content(CGSize(width: SpotTokens.partsWidth, height: height))
                    .modifier(PartRing(id: part.id, host: context.host, ring: ring, isShown: hugs))
                    .frame(maxWidth: part.fillsWidth(as: look) ? .infinity : nil, minHeight: height, maxHeight: .infinity, alignment: part.fillsWidth(as: look) ? .leading : .center)
            }
        }
        .background {
            Color.clear.modifier(PartRing(id: part.id, host: context.host, ring: ring, isShown: part.isFocusable && !ring.hugsControl))
        }
    }
}

private struct PartRing: ViewModifier {
    let id: String
    let host: any NodeHost
    let ring: FocusRing
    let isShown: Bool

    func body(content: Content) -> some View {
        if isShown {
            content.overlay {
                Color.clear
                    .modifier(SpotSelectionRing(isSelected: host.selectedPart == id, shape: SpotRoundShape(ring.edge)))
                    .padding(.horizontal, -ring.outset.width)
                    .padding(.vertical, -ring.outset.height)
            }
        } else {
            content
        }
    }
}
