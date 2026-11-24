import Foundation

public enum ContextShape: Sendable {
    case folded
    case spread
    case wide

    init(_ layout: ContextLayout) {
        self = !layout.isSpread ? .folded : layout.spreadCount > ContextStack.pile ? .wide : .spread
    }
}
