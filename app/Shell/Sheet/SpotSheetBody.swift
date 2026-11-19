import OpenspotCore
import SwiftUI

struct SpotSheetBody: View {
    let panel: SheetParts?
    let list: ItemList
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var onPick: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    var viewSource: String?
    var views = SpotViews.shared

    static func size(of panel: SheetParts?, rows: Int, setsApart: Bool = false) -> CGSize {
        panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(rows: rows, setsApart: setsApart)
    }

    var body: some View {
        if let panel {
            if panel.showsRows { Color.clear.frame(height: SpotTokens.listRow) }
            SheetPartsView(panel: panel, onSet: onSet, onPress: onPress, list: list, onRun: onPick, selection: selection, viewSource: viewSource, views: views)
        } else {
            SpotItemsView(list: list, onRun: onPick, onPoint: onPick, selection: selection)
        }
    }
}
