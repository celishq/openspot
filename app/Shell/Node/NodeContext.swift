import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotNode = NodeContext()
}

struct NodeContext: @MainActor Equatable {
    var variants: Set<Style.Variant> = [.sheet]
    var actions: any NodeActions = NoActions()
    var panel: SheetParts?
    var focus: FocusState<String?>.Binding?

    @MainActor static func == (one: NodeContext, other: NodeContext) -> Bool {
        one.variants == other.variants && one.panel == other.panel && one.actions.isSame(as: other.actions)
    }
}

private struct NoActions: NodeActions, @MainActor Equatable {
    func isSelected(_ node: ViewNode, in tree: ViewTree) -> Bool {
        false
    }
}
