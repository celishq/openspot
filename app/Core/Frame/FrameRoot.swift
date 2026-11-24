public struct FrameRoot: Equatable, Sendable {
    static let link = "link"

    public let block: TextBlock?
    public let isPicture: Bool
    public let isMark: Bool
    public let end: String?
    public let link: String?
    let index: Int?

    public init(text: String) {
        self.init(blocks: TextBlock.blocks(in: text), kinds: BlockKind.all)
    }

    init(blocks: [TextBlock], kinds: [BlockKind]) {
        isPicture = blocks.contains { block in block.fields.first.map { Self.isKind($0.key, in: kinds) } ?? false }
        index = blocks.firstIndex(where: RootKey.starts)
        block = index.map { blocks[$0] }
        isMark = !isPicture && blocks.allSatisfy { $0.fields.allSatisfy { RootKey.marks.contains($0.key) } }
        end = blocks.lazy.filter { RootKey.starts($0) || RootKey.isMark($0) }.compactMap { $0.value(RootKey.end) }.first
        link = blocks.lazy.filter { $0.fields.first?.key == Self.link }.compactMap { $0.value(Self.link) }.first
    }

    static func isKind(_ word: String, in kinds: [BlockKind]) -> Bool {
        BlockKind.lists.contains { $0.word == word } || kinds.contains { $0.word == word || $0.name == word }
    }
}
