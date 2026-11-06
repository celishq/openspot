import OpenspotCore
import SwiftUI

/// A sheet of parts on its own, with the header and size it has in the panel, for a picture or the sandbox.
struct SpotSheetPreview: View {
    let panel: SpotPanel
    var title = "Sheet"
    var subtitle = "Preview"
    var symbol = "square.dashed"
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var list = ItemList()

    var body: some View {
        let frame = SpotTokens.panelRect(panel)
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous)
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding - 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(Color.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(title).font(SpotType.title).foregroundStyle(.white)
                    Text(subtitle).font(SpotType.detail).modifier(SpotSecondaryText())
                }
                Spacer()
                SpotRoundButton(symbol: "xmark", label: "Close") {}
            }
            if panel.showsRows { Color.clear.frame(height: SpotTokens.listRowHeight) }
            SpotPanelView(panel: panel, onSet: onSet, onPress: onPress, list: list)
        }
        .padding(SpotTokens.padding)
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background(Color(white: 0.3), in: shape)
        .overlay { shape.strokeBorder(.white.opacity(0.25), lineWidth: 1) }
    }
}
