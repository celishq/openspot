import OpenspotCore
import SwiftUI

struct NodePart: View {
    let node: ViewNode
    let label: AnyView?
    var look: SpotPart.Look?
    @Environment(\.spotNodeParts) private var parts

    var body: some View {
        parts.part(node, label, look)
    }
}
