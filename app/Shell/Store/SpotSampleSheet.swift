import OpenspotCore
import SwiftUI

struct SpotSampleSheet: View {
    let model: SpotsModel
    let entry: SpotsModel.Entry
    let output: @MainActor () async -> Frame?
    @State private var sample: (panel: SheetParts?, list: ItemList)?
    @State private var selected = 0

    var body: some View {
        let size = SpotSheetBody.size(of: sample?.panel, list: sample?.list ?? ItemList())
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.wordsGap) {
                SpotGlyph(entry: entry)
                SpotSheetTitle(title: entry.spot.name, subtitle: entry.spot.subtitle)
            }
            if let sample {
                SpotSheetBody(panel: sample.panel, list: sample.list, search: entry.spot.name, onPick: pick(in: sample.list), onPoint: pick(in: sample.list), selection: { [selected] in selected })
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: SpotRoundShape(radius: SpotTokens.cardRadius))
        .modifier(SpotGlass())
        .environment(\.spotIsShown, true)
        .environment(\.spotViewPlace, SpotViewPlace(model: model, place: .sample))
        .environment(\.spotViewDates, entry.spot.viewDates)
        .task(id: entry.id) {
            for view in entry.spot.views.values { await SpotViews.shared.load(view) }
            guard let output = await output() else { return }
            sample = (SheetParts(output: output), SpotSheetPicture.list(of: output))
        }
    }

    private func pick(in list: ItemList) -> (SpotItem) -> Void {
        { item in selected = list.shown.firstIndex { $0 == item } ?? selected }
    }
}
