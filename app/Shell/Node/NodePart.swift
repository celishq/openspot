import SwiftUI

struct NodePart: View {
    let id: String
    let label: AnyView?
    @Environment(\.spotNodeParts) private var parts

    var body: some View {
        parts.part(id, label)
    }
}
