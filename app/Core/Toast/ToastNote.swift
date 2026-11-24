import Foundation

public struct ToastNote: Equatable, Sendable, ExpressibleByStringInterpolation {
    static let head = "toast"
    private static let keys: Set = [head, "title", "keep", "action"]

    public let id: String?
    public let words: String
    public let keeps: Bool
    public let action: String?

    public init(words: String) {
        id = nil
        self.words = words
        keeps = false
        action = nil
    }

    public init(stringLiteral words: String) {
        self.init(words: words)
    }

    init(blocks text: String) throws {
        let blocks = TextBlock.blocks(in: text)
        guard let head = blocks.first, head.fields.first?.key == Self.head else {
            throw SpotError.fault("A toast on stdin starts with a block of `toast=<id>`, such as `toast=upload` and `title=Uploading`.")
        }
        guard blocks.count == 1 else { throw SpotError.fault("A toast takes one block, `toast=<id>` with its `title`.") }
        if let key = head.fields.map(\.key).first(where: { !Self.keys.contains($0) }) {
            throw SpotError.fault("A toast has no key `\(key)`. Its block takes \(Self.keys.sorted().map { "`\($0)`" }.joined(separator: ", ")).")
        }
        let keep = head.value("keep")
        guard keep == nil || keep == "true" || keep == "false" else { throw SpotError.fault("`keep` of a toast takes `true` or `false`.") }
        guard let words = head.value("title"), !words.isEmpty else { throw SpotError.fault("A toast needs a `title`, the words it shows.") }
        let id = head.value(Self.head) ?? ""
        self.id = id.isEmpty ? nil : id
        self.words = words
        keeps = keep == "true"
        action = head.value("action").flatMap { $0.isEmpty ? nil : $0 }
    }

    private init(id: String?, words: String, keeps: Bool, action: String?) {
        self.id = id
        self.words = words
        self.keeps = keeps
        self.action = action
    }

    func hiding(_ values: FieldValues) -> ToastNote {
        ToastNote(id: id, words: values.hiding(words), keeps: keeps, action: action)
    }
}
