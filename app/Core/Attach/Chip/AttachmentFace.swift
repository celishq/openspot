import Foundation

public struct AttachmentFace: Hashable, Sendable {
    static let kinds: [BlockKind] = [.text, .number, .series, .picture, .icon]

    let blocks: [TextBlock]
    public let tree: ViewTree
    let errors: [String]

    init?(blocks: [TextBlock]) {
        guard !blocks.isEmpty else { return nil }
        let frame = Frame(grouped: Frame.grouping(blocks), kinds: Self.kinds)
        self.blocks = blocks
        tree = frame.tree
        errors = frame.errors
    }

    public static func == (one: AttachmentFace, other: AttachmentFace) -> Bool {
        one.blocks == other.blocks
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(blocks.map(\.firstLine))
    }
}
