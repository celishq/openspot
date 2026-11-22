import OpenspotCore
import SwiftUI

struct NodeSpotView: View {
    let id: String
    let values: [String: [String]]
    let source: String
    @Environment(\.spotNodeSend) private var send

    var body: some View {
        GeometryReader { area in
            SpotCustomView(source: source, values: values, card: .square, room: area.size, views: .shared, send: send.map { send in { [id] value in send(id, value) } })
                .equatable()
        }
    }
}
