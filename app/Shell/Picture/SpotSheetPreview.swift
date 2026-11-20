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
        let frame = SpotSheetBody.size(of: panel, rows: list.shown.count, perLine: list.perLine, setsApart: list.setsApart)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.wordsGap) {
                Image(systemName: symbol)
                    .font(SpotType.glyph)
                    .foregroundStyle(SpotTheme.ink)
                    .frame(width: SpotTokens.glyph, height: SpotTokens.glyph)
                    .background(SpotTheme.ink.opacity(SpotTheme.disc), in: Circle())
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(title).font(SpotType.title).foregroundStyle(SpotTheme.ink)
                    if !subtitle.isEmpty { Text(subtitle).font(SpotType.detail).modifier(SpotSecondaryText()) }
                }
                Spacer()
                SpotRoundButton(symbol: "xmark", label: "Close") {}
            }
            SpotSheetBody(panel: panel, list: list, onSet: onSet, onPress: onPress, viewSource: viewSource, views: views)
        }
        .padding(SpotTokens.padding)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background { SpotPictureStage(size: frame, radius: SpotTokens.cardRadius, seed: seed) { Color.clear.spotGlass(in: SpotRoundShape(radius: SpotTokens.cardRadius)) }.padding(-SpotPictureStage<Color>.margin) }
    }
}
