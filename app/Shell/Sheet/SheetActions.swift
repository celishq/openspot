import OpenspotCore
import SwiftUI

struct SheetActions: NodeActions, @MainActor Equatable {
    let model: SpotsModel
    let id: String
    let content: SheetContent
    let isHeld: Bool

    static func == (one: SheetActions, other: SheetActions) -> Bool {
        one.model === other.model && one.id == other.id && !one.isHeld && !other.isHeld
    }

    private var panel: SheetParts? {
        isHeld ? content.panel : model.sheets[id]?.panel
    }

    func part(of node: ViewNode) -> SpotPart? {
        isHeld ? node.part : model.sheets[id]?[part: node.id] ?? node.part
    }

    func set(_ part: SpotPart, to value: String) {
        model.setPart(part, to: value)
    }

    func press(_ part: SpotPart) {
        model.pressPart(part)
    }

    func record(_ part: SpotPart) {
        model.toggleRecording(part)
    }

    func focus(_ part: SpotPart) {
        model.focusPart(part)
    }

    func act(of part: SpotPart) -> ScriptCall? {
        content.act(part)
    }

    func run(_ item: SpotItem) {
        model.runItem(item)
    }

    func dragOut(_ items: [SpotItem]) {
        model.dragOut(items, of: id)
    }

    var send: ((String, String) -> Void)? {
        { [content, model] id, value in
            if let part = content.panel?.tree.node(id)?.part { model.setPart(part, to: value) }
        }
    }

    var selectedPart: String? {
        content.selectedPart()
    }

    var recordingPart: String? {
        isHeld ? content.recording : model.recording
    }

    var keys: KeyRecording? {
        isHeld ? content.keys : model.keys
    }

    var nudge: SheetParts.Nudge {
        content.nudge()
    }

    var menuOpening: SheetParts.MenuOpening? {
        content.menuOpening()
    }

    var list: ItemList? {
        isHeld ? content.list : model.sheets[id]?.list ?? ItemList()
    }

    var selection: (() -> Int)? {
        content.selection
    }

    var rows: [[String]] {
        panel?.rows ?? []
    }

    var answers: Int {
        panel?.answered ?? 0
    }
}
