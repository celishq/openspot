import OpenspotCore
import SwiftUI

struct SampleHost: NodeHost {
    let panel: SheetParts
    let items: ItemList
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    let onPick: (SpotItem) -> Void
    let picked: (() -> Int)?

    func set(_ part: SpotPart, to value: String) {
        onSet(part, value)
    }

    func press(_ part: SpotPart) {
        onPress(part)
    }

    func run(_ item: SpotItem) {
        onPick(item)
    }

    var send: ((String, String) -> Void)? {
        { [panel, onSet] id, value in
            if let part = panel.tree.node(id)?.part { onSet(part, value) }
        }
    }

    var selectedPart: String? {
        panel.selectedPart?.id
    }

    var list: ItemList? {
        items
    }

    var selection: (() -> Int)? {
        picked
    }

    var rows: [[String]] {
        panel.rows
    }

    var answers: Int {
        panel.answered
    }
}
