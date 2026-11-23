import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotNode = NodeContext()
}

struct NodeContext: @MainActor Equatable {
    var variants: Set<Style.Variant> = [.sheet]
    var host: any NodeHost = NoHost()
    var panel: SheetParts?
    var focus: FocusState<String?>.Binding?

    @MainActor static func == (one: NodeContext, other: NodeContext) -> Bool {
        one.variants == other.variants && one.panel == other.panel && one.host.isSame(as: other.host)
    }
}

private struct NoHost: NodeHost, @MainActor Equatable {
    func isSelected(_ node: ViewNode, in tree: ViewTree) -> Bool {
        false
    }
}
