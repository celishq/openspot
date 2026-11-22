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

    init(id: String, kind: String, parent: String?, block: TextBlock, style: Style, children: [String]) {
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
    }
}
