import Foundation

public struct ToastNote: Equatable, Sendable, ExpressibleByStringInterpolation {
    static let head = "toast"
    private static let keys: Set = [head, "title", "keep", "action", ViewNode.classKey]

    public let id: String?
    public let words: String
    public let keeps: Bool
    public let action: String?
    public let tree: ViewTree?
    private let source: String?

    public init(words: String) {
        id = nil
        self.words = words
        keeps = false
        action = nil
        tree = nil
        source = nil
    }

    public init(stringLiteral words: String) {
        self.init(words: words)
    }

    init(blocks text: String) throws {
        let blocks = TextBlock.blocks(in: text)
        guard let head = blocks.first, head.fields.first?.key == Self.head else {
            throw SpotError.fault("A toast on stdin starts with a block of `toast=<id>`, such as `toast=upload` and `title=Uploading`.")
        }
        if let key = head.fields.map(\.key).first(where: { !Self.keys.contains($0) }) {
            throw SpotError.fault("A toast has no key `\(key)`. Its first block takes \(Self.keys.sorted().map { "`\($0)`" }.joined(separator: ", ")).")
        }
        let keep = head.value("keep")
        guard keep == nil || keep == "true" || keep == "false" else { throw SpotError.fault("`keep` of a toast takes `true` or `false`.") }
        let parts = Array(blocks.dropFirst())
        if let other = parts.first(where: { !BlockKind.words.contains($0.fields.first?.key ?? "") }) {
            throw SpotError.fault("A toast draws only Openspot's own blocks, such as `text`, `number` or `icon`: \(other.firstLine)")
        }
        let tree = parts.isEmpty ? nil : ViewTree(blocks: Frame.grouping(parts), root: head, kinds: BlockKind.all, isWritten: true)
        if let fault = tree?.faults.first { throw SpotError.fault("A toast \(fault).") }
        let words = head.value("title") ?? ""
        guard tree != nil || !words.isEmpty else { throw SpotError.fault("A toast needs a `title`, the words it shows, or blocks to draw.") }
        let id = head.value(Self.head) ?? ""
        self.id = id.isEmpty ? nil : id
        self.words = words
        keeps = keep == "true"
        action = head.value("action").flatMap { $0.isEmpty ? nil : $0 }
        self.tree = tree
        source = text
    }

    func hiding(_ values: FieldValues) -> ToastNote {
        guard let source else { return ToastNote(words: values.hiding(words)) }
        return (try? ToastNote(blocks: values.hiding(source))) ?? self
    }
}
