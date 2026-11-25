import OpenspotCore
import SwiftUI

struct NodeBox: View {
    let children: [String]
    let style: Style
    let tree: ViewTree
    var outset: CGFloat = 0

    private static let arrival = AnyTransition.opacity

    var body: some View {
        if style.scrolls {
            ScrollView(.vertical) { arrangement }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled()
                .mask { Rectangle().padding(.horizontal, -SpotTokens.padding) }
        } else {
            arrangement
        }
    }

    private var arrangement: some View {
        NodeArrangement(style: style, outset: outset) {
            ForEach(children, id: \.self) { id in
                if let node = tree.node(id) {
                    NodeView(node: node, tree: tree)
                        .transition(Self.arrival)
                }
            }
        }
    }
}
