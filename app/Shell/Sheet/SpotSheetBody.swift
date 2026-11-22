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

    static func size(of panel: SheetParts?, list: ItemList) -> CGSize {
        panel.map { SpotTokens.panelRect($0).size } ?? SpotTokens.floatSize(list: list)
    }

    var body: some View {
        if let panel {
            if panel.top.hasField { SpotSheetSearchRow(title: title) }
            SheetPartsView(panel: panel, actions: SampleActions(panel: panel, items: list, onSet: onSet, onPress: onPress, onPick: onPick, picked: selection))
                .environment(\.spotSearchTitle, title)
        } else {
            SpotItemsView(list: list, onRun: onPick, onPoint: onPick, selection: selection)
        }
    }
}
