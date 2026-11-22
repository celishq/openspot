import OpenspotCore
import SwiftUI

struct NodeSpotView: View {
    let id: String
    let values: [String: [String]]
    let source: String
    @Environment(\.spotNodeSend) private var send
    @Environment(\.spotNodeViewInput) private var input
    @Environment(\.spotNodeVariants) private var variants

    var body: some View {
        let card = SpotSize.all.first { size in Style.Variant(size: size).map(variants.contains) == true }
        GeometryReader { area in
            SpotSelectionScope(run: SpotViews.shared.readsSelection(source) ? input.selection : { nil }) { run in
                SpotCustomView(source: source, values: values, items: input.items, card: card ?? .square, room: area.size, answers: input.answers, selection: run, views: .shared, send: send.map { send in { [id] value in send(id, value) } }, namesCard: card != nil)
                    .equatable()
            }
        }
    }
}
