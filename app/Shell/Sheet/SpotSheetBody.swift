import OpenspotCore
import SwiftUI

struct SpotSheetBody: View {
    let panel: SheetParts?
    let list: ItemList
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var onPick: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    var title = ""

    static func size(of panel: SheetParts?, rows: Int, perLine: Int, setsApart: Bool = false) -> CGSize {
        panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(rows: rows, perLine: perLine, setsApart: setsApart)
    }

    var body: some View {
        if let panel {
            if panel.top.hasField { SpotSheetSearchRow(title: title) }
            SheetPartsView(panel: panel, onSet: onSet, onPress: onPress, list: list, onRun: onPick, selection: selection)
        } else {
            SpotItemsView(list: list, onRun: onPick, onPoint: onPick, selection: selection)
        }
    }
}
