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
        let frame = SpotSheetBody.size(of: panel, rows: list.shown.count)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.wordsGap) {
                Image(systemName: symbol)
                    .font(SpotType.glyph)
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
            SpotSheetBody(panel: panel, list: list, onSet: onSet, onPress: onPress, viewSource: viewSource, views: views)
        }
        .padding(SpotTokens.padding)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background { SpotPictureStage(size: frame, radius: SpotTokens.radius, seed: seed) { Color.clear.spotGlass(in: SpotRoundShape(radius: SpotTokens.radius)) }.padding(-SpotPictureStage<Color>.margin) }
    }
}
