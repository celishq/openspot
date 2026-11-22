import OpenspotCore
import SwiftUI

struct SpotSheetBody: View {
    @Environment(\.spotSearchTitle) private var searchTitle
    @Environment(\.spotIsHeld) private var isHeld
    let panel: SheetParts?
    let list: ItemList
    var search: String?
    var act: (SpotPart) -> ScriptCall? = { _ in nil }
    var onSet: (SpotPart, String) -> Void = { _, _ in }
    var onPress: (SpotPart) -> Void = { _ in }
    var recording: String?
    var recordingWords = "Press keys"
    var onRecord: (SpotPart) -> Void = { _ in }
    var keys: KeyRecording?
    var onPick: (SpotItem) -> Void = { _ in }
    var onPoint: (SpotItem) -> Void = { _ in }
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var selection: (() -> Int)?
    var selectedPart: (() -> String?)?
    var nudge: () -> SheetParts.Nudge = { SheetParts.Nudge.rest }
    var menuOpening: () -> SheetParts.MenuOpening? = { nil }
    var onFocus: (SpotPart) -> Void = { _ in }
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
            SheetPartsView(
                panel: panel,
                act: act,
                onSet: onSet,
                onPress: onPress,
                recordingPart: recording,
                onRecord: onRecord,
                keys: keys,
                list: list,
                onRun: onPick,
                onDragOut: onDragOut,
                selection: selection,
                selectedPart: selectedPart,
                nudge: nudge,
                menuOpening: menuOpening,
                onFocus: onFocus
            )
            .environment(\.spotSearchTitle, search ?? searchTitle)
        } else {
            SpotItemsView(list: list, recording: isHeld ? nil : recording, recordingWords: recordingWords, keys: keys, onRun: onPick, onPoint: onPoint, selection: selection, onDragOut: onDragOut, failure: failure, tips: tips, shakes: shakes, room: room)
        }
    }
}
