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
        return Group {
            if hasLabel {
                content(natural)
            } else if part.fillsHeight {
                GeometryReader { room in
                    content(room.size)
                }
                .frame(minHeight: height, idealHeight: height)
                .frame(idealWidth: natural.width)
            } else {
                content(CGSize(width: SpotTokens.partsWidth, height: height))
                    .frame(maxWidth: part.fillsWidth(as: look) ? .infinity : nil, minHeight: height, maxHeight: .infinity, alignment: part.fillsWidth(as: look) ? .leading : .center)
            }
        }
        .background {
            if part.isFocusable {
                Color.clear.modifier(PartRing(id: part.id, host: context.host, hasBox: hasLabel || hasBox, shape: SpotRoundShape(surface.inner())))
            }
        }
    }

    private var hasBox: Bool {
        if part.isEditable || look == .tile { return true }
        guard part.press == .line else { return false }
        return switch look {
        case .chip, .bare: false
        default: true
        }
    }
}

private struct PartRing: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let id: String
    let host: any NodeHost
    let hasBox: Bool
    let shape: SpotRoundShape

    func body(content: Content) -> some View {
        let isSelected = host.selectedPart == id
        if hasBox {
            let gap = SpotTokens.focusGap
            let ring = SpotRoundShape(surface.inner(by: SpotTokens.padding - gap))
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: ring)).padding(-gap)
        } else {
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: shape)).padding(.horizontal, -SpotTokens.controlPadding)
        }
    }
}
