import OpenspotCore
import SwiftUI

struct NodePart: View {
    let id: String
    let label: AnyView?
    var look: SpotPart.Look?
    @Environment(\.spotNodeParts) private var parts

    var body: some View {
        parts.part(id, label, look)
    }
}
