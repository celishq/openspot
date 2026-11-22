import OpenspotCore
import SwiftUI

struct NodeItems: View {
    let size: CGSize
    @Environment(\.spotNode) private var context

    var body: some View {
        GeometryReader { room in
            if let list = context.actions.list {
                let actions = context.actions
                SpotItemsView(list: list, onRun: { actions.run($0) }, selection: actions.selection, onDragOut: { actions.dragOut($0) }, room: room.size.height)
                    .mask(alignment: .top) { Rectangle().frame(height: room.size.height + SpotTokens.padding) }
            }
        }
        .frame(idealWidth: size.width, idealHeight: size.height)
    }
}
