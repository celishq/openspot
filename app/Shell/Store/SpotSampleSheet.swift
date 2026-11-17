import OpenspotCore
import SwiftUI

struct SpotSampleSheet: View {
    let model: SpotsModel
    let id: String
    let entry: SpotsModel.Entry
    @State private var sample: (panel: SheetParts?, list: ItemList)?
    @State private var selected = 0

    var body: some View {
        let size = SpotSheetBody.size(of: sample?.panel, rows: sample?.list.shown.count ?? 0, setsApart: sample?.list.setsApart ?? false)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.wordsGap) {
                SpotGlyph(entry: entry)
                SpotSheetTitle(title: entry.spot.name, subtitle: entry.spot.subtitle)
            }
            if let sample {
                SpotSheetBody(panel: sample.panel, list: sample.list, onPick: pick(in: sample.list), selection: { selected }, viewSource: entry.spot.view)
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass())
        .environment(\.spotIsShown, true)
        .environment(\.spotViewPlace, SpotViewPlace(model: model, place: .sample))
        .task(id: entry.id) {
            if let view = entry.spot.view { await SpotViews.shared.load(view) }
            guard let output = await model.sample(id) else { return }
            sample = (SheetParts(output: output), SpotSheetPicture.list(of: output))
        }
    }

    private func pick(in list: ItemList) -> (SpotItem) -> Void {
        { item in selected = list.shown.firstIndex { $0 == item } ?? selected }
    }
}
