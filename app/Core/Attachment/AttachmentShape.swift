import Foundation

public enum AttachmentShape: Sendable {
    case folded
    case spread
    case wide

    init(_ layout: AttachmentLayout) {
        self = !layout.isSpread ? .folded : layout.spreadCount > AttachmentStack.pile ? .wide : .spread
    }
}
