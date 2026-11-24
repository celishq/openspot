import Foundation

public struct ToastNote: Equatable, Sendable, ExpressibleByStringInterpolation {
    static let head = "toast"
    private static let keys: Set = [head, "title", "action", ViewNode.classKey]

    public let id: String?
    public let words: String
    public let action: String?
    public let tree: ViewTree?
    public let kind: ToastKind
    public let fix: ToastFix?
    private let source: Source?

    public init(words: String, kind: ToastKind = .confirm, fix: ToastFix? = nil) {
        id = nil
        self.words = words
        self.kind = kind
        self.fix = fix
        action = nil
        tree = nil
        source = nil
    }

    public static func failure(_ words: String, fix: ToastFix? = nil) -> ToastNote {
        ToastNote(words: words, kind: .failure, fix: fix)
    }

    public static func work(_ words: String) -> ToastNote {
        ToastNote(words: words, kind: .work)
    }

    public init(stringLiteral words: String) {
        self.init(words: words)
    }

    init(_ source: Source) throws {
        var blocks = source.view.map(TextBlock.blocks(in:)) ?? []
        var given: [TextBlock.Field] = []
        if let first = blocks.first, first.fields.first?.key == Self.head {
            if let key = first.fields.map(\.key).first(where: { !Self.keys.contains($0) }) {
                throw SpotError.fault("A toast has no key `\(key)`. Its first block takes \(Self.keys.sorted().map { "`\($0)`" }.joined(separator: ", ")).")
            }
            given = first.fields
            blocks.removeFirst()
        }
        let flags: [(String, String?)] = [(Self.head, source.id), ("title", source.words), ("action", source.action), (ViewNode.classKey, source.classes)]
        for (key, value) in flags {
            guard let value else { continue }
            given.removeAll { $0.key == key }
            given.append(.init(key: key, value: value))
        }
        let head = TextBlock(fields: given)
        if let other = blocks.first(where: { !BlockKind.words.contains($0.fields.first?.key ?? "") }) {
            throw SpotError.fault("A toast draws only Openspot's own blocks, such as `text`, `number` or `icon`: \(other.firstLine)")
        }
        let tree = blocks.isEmpty ? nil : ViewTree(blocks: Frame.grouping(blocks), root: head, kinds: BlockKind.all, isWritten: true)
        if let fault = tree?.faults.first { throw SpotError.fault("A toast \(fault).") }
        let words = head.value("title") ?? ""
        guard tree != nil || !words.isEmpty else { throw SpotError.fault("A toast needs words to show, or a view to draw.") }
        let id = head.value(Self.head) ?? ""
        self.id = id.isEmpty ? nil : id
        self.words = words
        action = head.value("action").flatMap { $0.isEmpty ? nil : $0 }
        self.tree = tree
        kind = .confirm
        fix = nil
        self.source = source
    }

    func hiding(_ values: FieldValues) -> ToastNote {
        guard let source else { return ToastNote(words: values.hiding(words), kind: kind, fix: fix) }
        return (try? ToastNote(source.hiding(values))) ?? self
    }
}
