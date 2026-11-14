import Foundation

public struct SpotHeader: Equatable, Sendable {
    private static let limit = 4096
    private static let marks = ["//", "--", "#"]
    private static let kinds: Set<String> = ["button", "field", "command", "setting"]

    public let block: TextBlock

    public init(text: String) {
        var lines: [String] = []
        var rest = text[...]
        var isFirst = true
        while let line = Self.nextLine(of: &rest) {
            defer { isFirst = false }
            if isFirst, line.hasPrefix("#!") { continue }
            guard let mark = Self.marks.first(where: { line.hasPrefix($0) }) else { break }
            lines.append(line.dropFirst(mark.count).trimmingCharacters(in: .whitespaces))
        }
        var keys: [TextBlock.Field] = []
        var children: [TextBlock] = []
        for block in TextBlock.blocks(in: lines.joined(separator: "\n")) {
            if let kind = block.fields.first?.key, Self.kinds.contains(kind) {
                children.append(block)
            } else {
                keys += block.fields
            }
        }
        block = TextBlock(fields: keys, children: children)
    }

    private static func nextLine(of text: inout Substring) -> Substring? {
        guard !text.isEmpty else { return nil }
        guard let end = text.firstIndex(of: "\n") else {
            defer { text = text[text.endIndex...] }
            return text
        }
        defer { text = text[text.index(after: end)...] }
        return text[..<end]
    }

    public init(url: URL) {
        let file = try? FileHandle(forReadingFrom: url)
        let data = (try? file?.read(upToCount: Self.limit)) ?? Data()
        try? file?.close()
        self.init(text: String(decoding: data, as: UTF8.self))
    }
}
