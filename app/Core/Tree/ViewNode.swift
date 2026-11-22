import Foundation

public struct ViewNode: Equatable, Sendable, Identifiable {
    static let parentKey = "parent"
    static let classKey = "class"
    static let multiline = "multiline"
    static let commonKeys: Set<String> = [parentKey, classKey, "title", "detail", "tone", "icon"]

    public let id: String
    public let kind: String
    public let parent: String?
    public let block: TextBlock
    public let style: Style
    public let children: [String]
    public internal(set) var part: SpotPart?
    public let value: String?
    public let icon: Icon?
    public let source: String?
    public let values: [String: [String]]
    public let isSearch: Bool
    private let lines: Int

    public var title: String? {
        part?.title
    }

    public var detail: String? {
        part?.detail
    }

    public var tone: MetricValue.Tone? {
        part?.tone
    }

    public var naturalSize: CGSize {
        switch kind {
        case BlockKind.icon.word: CGSize(width: SpotTokens.listIconSize, height: SpotTokens.listIconSize)
        case BlockKind.picture.word: CGSize(width: SpotTokens.cell, height: SpotTokens.cell)
        default: CGSize(width: SpotTokens.cell, height: source == nil ? SpotTokens.listRow * CGFloat(lines) + SpotTokens.partGap * CGFloat(lines - 1) : SpotTokens.cell)
        }
    }

    init(id: String, kind: String, parent: String?, block: TextBlock, style written: Style, children: [String], blockKind: BlockKind?) {
        self.id = id
        self.kind = kind
        self.parent = parent
        self.block = block
        let part = blockKind.flatMap { SpotPart(block: block, kind: $0, style: written) }
        self.part = part
        var style = written
        if style.grows == nil {
            let isMultiline = kind == BlockKind.field.word && block.value("type") == Self.multiline
            let isFree = blockKind?.source != nil && style.height == nil && !style.isSquare
            style.grows = block.flag("grow") ?? (kind == BlockKind.items || isMultiline || isFree ? true : nil)
        }
        self.style = style
        self.children = children
        value = block.value("value")
        icon = kind == BlockKind.icon.word ? Icon(text: value) : part?.icon
        source = blockKind?.source
        lines = blockKind == .hotkey ? 2 : 1
        isSearch = kind == BlockKind.field.word && block.value("type") == Frame.searchType
        values = source == nil ? [:] : Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) }
    }
}
