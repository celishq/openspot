import Foundation

public enum ContextRow: Sendable {
    case folded
    case spread
    case wide

    init(_ stack: ContextStack) {
        self = !stack.isSpread ? .folded : stack.rowCount > ContextStack.pile ? .wide : .spread
    }
}
