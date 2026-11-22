import Foundation

public struct ViewNode: Equatable, Sendable, Identifiable {
    static let parentKey = "parent"
    static let classKey = "class"

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

    init(id: String, kind: String, parent: String?, block: TextBlock, style: Style, children: [String], source: String? = nil) {
        self.id = id
        self.kind = kind
        self.parent = parent
        self.block = block
        self.style = style
        self.children = children
        title = block.value("title")
        detail = block.value("detail")
        value = block.value("value")
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
        icon = Icon(text: block.value(kind == BlockKind.icon.word ? "value" : "icon"))
        self.source = source
        values = source == nil ? [:] : Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) }
    }
}
