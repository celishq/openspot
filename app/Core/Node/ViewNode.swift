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
    public let title: String?
    public let detail: String?
    public let value: String?
    public let tone: MetricValue.Tone?
    public let icon: Icon?
    public let source: String?
    public let values: [String: [String]]
    private let lines: Int

    public var naturalSize: CGSize {
        switch kind {
        case BlockKind.icon.word: CGSize(width: SpotTokens.listIconSize, height: SpotTokens.listIconSize)
        case BlockKind.picture.word: CGSize(width: SpotTokens.cell, height: SpotTokens.cell)
        default: CGSize(width: SpotTokens.cell, height: source == nil ? SpotTokens.listRow * CGFloat(lines) + SpotTokens.partGap * CGFloat(lines - 1) : SpotTokens.cell)
        }
    }

    init(id: String, kind: String, parent: String?, block: TextBlock, style: Style, children: [String], part: BlockKind?) {
        self.id = id
        self.kind = kind
        self.parent = parent
        self.block = block
        var style = style
        if style.grows == nil {
            let isMultiline = kind == BlockKind.field.word && block.value("type") == Self.multiline
            let isFree = part?.source != nil && style.height == nil && !style.isSquare
            style.grows = block.flag("grow") ?? (kind == BlockKind.items || isMultiline || isFree ? true : nil)
        }
        self.style = style
        self.children = children
        title = block.value("title")
        detail = block.value("detail")
        value = block.value("value")
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
        icon = Icon(text: block.value(kind == BlockKind.icon.word ? "value" : "icon"))
        source = part?.source
        lines = part == .hotkey ? 2 : 1
        values = source == nil ? [:] : Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) }
    }
}
