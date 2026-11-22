import OpenspotCore
import SwiftUI

struct FloatActions: NodeActions, @MainActor Equatable {
    let model: SpotsModel
    let run: SpotRun
    let place: SheetPlace

    static func == (one: FloatActions, other: FloatActions) -> Bool {
        one.model === other.model && one.run === other.run && one.place == other.place
    }

    func part(of node: ViewNode) -> SpotPart? {
        run[part: node.id] ?? node.part
    }

    func set(_ part: SpotPart, to value: String) {
        run.set(part, to: value)
    }

    func press(_ part: SpotPart) {
        run.press(part)
        if part.closes { model.land(run.spot.id) }
    }

    func act(of part: SpotPart) -> ScriptCall? {
        run.act(of: part)
    }

    func run(_ item: SpotItem) {
        guard let entry = model.card(id: run.spot.id) else { return }
        model.pick(item, of: entry, in: place)
    }

    func dragOut(_ items: [SpotItem]) {
        model.dragOut(items, of: run.spot.id)
    }

    var send: ((String, String) -> Void)? {
        { [run] id, value in
            if let part = run.panel?.tree.node(id)?.part { run.set(part, to: value) }
        }
    }

    var selectedPart: String? {
        run.selectedPart?.id
    }

    var nudge: SheetParts.Nudge {
        run.nudge
    }

    var list: ItemList? {
        run.list
    }

    var selection: (() -> Int)? {
        { [run] in run.selection }
    }

    var rows: [[String]] {
        run.panel?.rows ?? []
    }

    var answers: Int {
        run.panel?.answered ?? 0
    }
}
