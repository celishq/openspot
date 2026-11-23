import OpenspotCore
import SwiftUI

struct NodeItems: View {
    let size: CGSize
    @Environment(\.spotNode) private var context

    var body: some View {
        GeometryReader { room in
            if let list = context.host.list {
                let host = context.host
                SpotItemsView(list: list, onRun: { host.run($0) }, selection: host.selection, onDragOut: { host.dragOut($0) }, room: room.size.height)
                    .mask(alignment: .top) { Rectangle().frame(height: room.size.height + SpotTokens.padding) }
            }
        }
        .frame(idealWidth: size.width, idealHeight: size.height)
    }
}
