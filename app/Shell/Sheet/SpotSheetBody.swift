import OpenspotCore
import SwiftUI

struct SpotSheetBody: View {
    @Environment(\.spotSearchTitle) private var searchTitle
    @Environment(\.spotIsHeld) private var isHeld
    let panel: SheetParts?
    let list: ItemList
    var host: (any NodeHost)?
    var search: String?
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var recording: String?
    var recordingWords = "Press keys"
    var keys: KeyRecording?
    var onPick: (SpotItem) -> Void = { _ in }
    var onPoint: (SpotItem) -> Void = { _ in }
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var selection: (() -> Int)?
    var failure: (String) -> String? = { _ in nil }
    var tips: SpotsModel?
    var shakes: (String) -> Int = { _ in 0 }
    var room = SpotTokens.listRoom

    static func size(of panel: SheetParts?, list: ItemList) -> CGSize {
        panel.flatMap { $0.holdsParts ? SpotTokens.panelRect($0).size : nil } ?? SpotTokens.floatSize(list: list)
    }

    var body: some View {
        if let panel, panel.holdsParts {
            if let search, panel.top.hasField { SpotSheetSearchRow(title: search) }
            SheetPartsView(panel: panel, host: host ?? SampleHost(panel: panel, items: list, onSet: onSet, onPress: onPress, onPick: onPick, picked: selection))
                .environment(\.spotSearchTitle, search ?? searchTitle)
        } else {
            SpotItemsView(list: list, recording: isHeld ? nil : recording, recordingWords: recordingWords, keys: keys, onRun: onPick, onPoint: onPoint, selection: selection, onDragOut: onDragOut, failure: failure, tips: tips, shakes: shakes, onNearEnd: { host?.nearsEnd() }, room: room)
        }
    }
}
