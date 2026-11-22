import OpenspotCore
import SwiftUI

struct NodeItems: View {
    @Environment(\.spotNodeParts) private var parts

    var body: some View {
        GeometryReader { room in
            parts.items(room.size.height)
        }
        .frame(idealWidth: SpotTokens.cell, idealHeight: SpotTokens.listRow)
    }
}
