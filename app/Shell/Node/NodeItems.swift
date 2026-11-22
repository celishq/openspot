import OpenspotCore
import SwiftUI

struct NodeItems: View {
    @Environment(\.spotNodeParts) private var parts

    var body: some View {
        GeometryReader { room in
            parts.items(room.size.height)
                .mask(alignment: .top) { Rectangle().frame(height: room.size.height + SpotTokens.padding) }
        }
        .frame(idealWidth: SpotTokens.cell, idealHeight: SpotTokens.listRow)
    }
}
