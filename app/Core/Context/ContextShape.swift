import Foundation

public enum ContextShape: Sendable {
    case folded
    case spread
    case wide

    init(_ stack: ContextStack) {
        self = !stack.isSpread ? .folded : stack.spreadCount > ContextStack.pile ? .wide : .spread
    }
}
