import OpenspotCore
import SwiftUI

struct SpotSampleSheet: View {
    let model: SpotsModel
    let id: String
    let entry: SpotsModel.Entry
    @State private var output: SpotOutput?
    @State private var selected = 0

    var body: some View {
        let panel = output.flatMap(SheetParts.init(output:))
        let list = output.map(SpotSheetPicture.list(of:)) ?? ItemList()
        let size = panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(rows: list.shown.count)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding - 5) {
                SpotGlyph(entry: entry)
                SpotSheetTitle(title: entry.spot.name, subtitle: entry.spot.subtitle)
            }
            if let panel {
                SheetPartsView(panel: panel, onSet: { _, _ in }, onPress: { _ in }, list: list, onRun: pick(in: list), selection: { selected }, viewSource: entry.spot.view)
            } else if output != nil {
                SpotRowsView(list: list, onRun: pick(in: list), onPoint: pick(in: list), selection: { selected })
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass())
        .environment(\.spotIsShown, true)
        .task(id: entry.id) {
            if let view = entry.spot.view { await SpotViews.shared.load(view) }
            output = await model.sample(id)
        }
    }

    private func pick(in list: ItemList) -> (SpotItem) -> Void {
        { item in selected = list.shown.firstIndex { $0 == item } ?? selected }
    }
}
