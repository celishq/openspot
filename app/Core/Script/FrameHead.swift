public struct FrameHead: Equatable, Sendable {
    public let block: TextBlock?
    public let isPicture: Bool
    public let isMark: Bool
    let index: Int?

    public init(text: String) {
        self.init(blocks: TextBlock.blocks(in: text), kinds: BlockKind.all)
    }

    init(blocks: [TextBlock], kinds: [BlockKind]) {
        isPicture = blocks.contains { block in block.fields.first.map { Self.isKind($0.key, in: kinds) } ?? false }
        index = blocks.firstIndex { block in block.fields.first.map { HeadKey.isKey($0.key) } ?? false }
        block = index.map { blocks[$0] }
        isMark = !isPicture && blocks.allSatisfy { $0.fields.allSatisfy { $0.key == HeadKey.call.rawValue || $0.key == HeadKey.end.rawValue } }
    }

    public var end: String? {
        block?.value(HeadKey.end)
    }

    public var link: String? {
        block?.value(HeadKey.link)
    }

    static func isKind(_ word: String, in kinds: [BlockKind]) -> Bool {
        word == BlockKind.row || word == BlockKind.repeated || word == BlockKind.option || kinds.contains { $0.word == word || $0.name == word }
    }
}
