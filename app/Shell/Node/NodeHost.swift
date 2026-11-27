import OpenspotCore
import SwiftUI

@MainActor
protocol NodeHost {
    func part(of node: ViewNode) -> SpotPart?
    func set(_ part: SpotPart, to value: String)
    func press(_ part: SpotPart)
    func record(_ part: SpotPart)
    func focus(_ part: SpotPart)
    func act(of part: SpotPart) -> ScriptCall?
    func run(_ item: SpotItem)
    func dragOut(_ items: [SpotItem])
    func nearsEnd()
    func slot(_ id: String, _ value: String?)
    func isSelected(_ node: ViewNode, in tree: ViewTree) -> Bool
    func selectedRun() -> String?
    var send: ((String, String) -> Void)? { get }
    var selectedPart: String? { get }
    var recordingPart: String? { get }
    var keys: KeyRecording? { get }
    var nudge: SheetParts.Nudge { get }
    var menuOpening: SheetParts.MenuOpening? { get }
    var list: ItemList? { get }
    var selection: (() -> Int)? { get }
    var rows: [[String]] { get }
    var answers: Int { get }
    var isSettled: Bool { get }
    func isSame(as other: any NodeHost) -> Bool
}

extension NodeHost {
    func part(of node: ViewNode) -> SpotPart? { node.part }
    func nearsEnd() {}
    func set(_ part: SpotPart, to value: String) {}
    func press(_ part: SpotPart) {}
    func record(_ part: SpotPart) {}
    func focus(_ part: SpotPart) {}
    func act(of part: SpotPart) -> ScriptCall? { nil }
    func run(_ item: SpotItem) {}
    func dragOut(_ items: [SpotItem]) {}
    func slot(_ id: String, _ value: String?) {}
    func isSelected(_ node: ViewNode, in tree: ViewTree) -> Bool { tree.isSelected(node) { selectedPart } }
    func selectedRun() -> String? { list.flatMap { list in list.run(at: (selection ?? { list.selected })()) } }
    var send: ((String, String) -> Void)? { nil }
    var selectedPart: String? { nil }
    var recordingPart: String? { nil }
    var keys: KeyRecording? { nil }
    var nudge: SheetParts.Nudge { .rest }
    var menuOpening: SheetParts.MenuOpening? { nil }
    var list: ItemList? { nil }
    var selection: (() -> Int)? { nil }
    var rows: [[String]] { [] }
    var answers: Int { 0 }
    var isSettled: Bool { true }
    func isSame(as other: any NodeHost) -> Bool { false }
}

extension NodeHost where Self: Equatable {
    func isSame(as other: any NodeHost) -> Bool {
        (other as? Self) == self
    }
}
