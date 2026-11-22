import SwiftUI

extension EnvironmentValues {
    @Entry var spotNodeViewInput = NodeViewInput()
}

struct NodeViewInput {
    var items: [[String]] = []
    var answers = 0
    var selection: () -> String? = { nil }
}
