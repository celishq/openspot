import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotNodeParts = NodeParts()
}

struct NodeParts {
    var part: @MainActor (String, AnyView?, SpotPart.Look?, CGSize) -> AnyView = { _, _, _, _ in AnyView(EmptyView()) }
    var items: @MainActor (CGFloat) -> AnyView = { _ in AnyView(EmptyView()) }
}
