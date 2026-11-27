import Foundation

public struct ViewNode: Equatable, Sendable, Identifiable {
    static let parentKey = "parent"
    static let classKey = "class"
    static let multiline = "multiline"
    static let commonKeys: Set<String> = [parentKey, classKey, "title", "detail", "tone", "icon"]

    public let id: String
    public let kind: BlockKind
    public let parent: String?
    public let block: TextBlock
    private let kept: StyleCache.Kept
    public let children: [String]
    public internal(set) var part: SpotPart?
    public let value: String?
    public let icon: Icon?
    public let source: String?
    public let values: [String: [String]]
    public let isSearch: Bool
    private let lines: Int

    public var style: Style {
        kept.style
    }

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
        case .icon: CGSize(width: SpotTokens.listIconSize, height: SpotTokens.listIconSize)
        case .picture: CGSize(width: SpotTokens.cell, height: SpotTokens.cell)
        default: CGSize(width: SpotTokens.cell, height: source == nil ? SpotTokens.listRow * CGFloat(lines) + SpotTokens.partGap * CGFloat(lines - 1) : SpotTokens.cell)
        }
    }

    init(id: String, kind: BlockKind, parent: String?, block: TextBlock, style written: Style, classes: String?, styles: StyleCache, children: [String], partKind: BlockKind?) {
        self.id = id
        self.kind = kind
        self.parent = parent
        self.block = block
        let part = partKind.flatMap { SpotPart(block: block, kind: $0, style: written) }
        self.part = part
        var style = written
        if style.grows == nil {
            let isMultiline = kind == .field && block.value("type") == Self.multiline
            let isFree = partKind?.source != nil && style.height == nil && !style.isSquare
            style.grows = block.flag("grow") ?? (kind == .items || isMultiline || isFree ? true : nil)
        }
        kept = styles.kept(style, classes: classes, grows: style.grows)
        self.children = children
        value = block.value("value")
        icon = kind == .icon ? Icon(text: value) : part?.icon
        source = partKind?.source
        lines = partKind == .hotkey ? 2 : 1
        isSearch = kind == .field && block.value("type") == Frame.searchType
        values = source == nil ? [:] : Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) }
    }
}
