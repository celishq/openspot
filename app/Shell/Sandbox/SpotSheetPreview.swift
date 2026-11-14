import OpenspotCore
import SwiftUI

struct SpotSheetPreview: View {
    let panel: SheetParts?
    var title = "Sheet"
    var subtitle = "Preview"
    var symbol = "square.dashed"
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var list = ItemList()
    var viewSource: String?
    var views = SpotViews.shared
    var seed = ""

    var body: some View {
        let frame = panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(rows: list.shown.count)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding - 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SpotTheme.ink)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(SpotTheme.ink.opacity(SpotTheme.disc), in: Circle())
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(title).font(SpotType.title).foregroundStyle(SpotTheme.ink)
                    if !subtitle.isEmpty { Text(subtitle).font(SpotType.detail).modifier(SpotSecondaryText()) }
                }
                Spacer()
                SpotRoundButton(symbol: "xmark", label: "Close") {}
            }
            if let panel {
                if panel.showsRows { Color.clear.frame(height: SpotTokens.listRowHeight) }
                SheetPartsView(panel: panel, onSet: onSet, onPress: onPress, list: list, viewSource: viewSource, views: views)
            } else {
                SpotRowsView(list: list, onRun: { _ in })
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background { SpotPictureStage(size: frame, radius: SpotTokens.radius, seed: seed) { Color.clear }.padding(-SpotPictureStage<Color>.margin) }
    }
}
