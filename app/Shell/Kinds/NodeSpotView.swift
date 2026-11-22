import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotViewDates: [String: Date] = [:]
}

struct NodeSpotView: View {
    let id: String
    let values: [String: [String]]
    let source: String
    @Environment(\.spotNode) private var context
    @Environment(\.spotViewDates) private var dates

    var body: some View {
        let card = SpotSize.all.first { size in Style.Variant(size: size).map(context.variants.contains) == true }
        let actions = context.actions
        GeometryReader { area in
            SpotSelectionScope(run: SpotViews.shared.readsSelection(source) ? { actions.selectedRun() } : { nil }) { run in
                SpotCustomView(source: source, values: values, items: actions.rows, card: card ?? .square, room: area.size, answers: actions.answers, selection: run, date: dates[source], views: .shared, send: actions.send.map { send in { [id] value in send(id, value) } }, namesCard: card != nil)
                    .equatable()
            }
        }
    }
}
