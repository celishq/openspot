import Foundation

/// The `key=value` comment lines at the top of a script, which say what it is without running it. They are a frame in
/// comments: a blank comment line ends a block, and a `command` or `setting` block follows the keys of the spot.
public struct PluginHeader: Equatable, Sendable {
    private static let limit = 4096
    private static let marks = ["//", "--", "#"]
    private static let kinds: Set<String> = ["command", "setting"]

    /// The keys of the spot, with each `command` and `setting` block as a child.
    public let block: TextBlock

    /// Reads the comment lines under the first line of a script. The first other line ends them, and a program has none.
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

    /// Takes the next line off the front of the text, so that a read stops at the end of the header and splits no more.
    private static func nextLine(of text: inout Substring) -> Substring? {
        guard !text.isEmpty else { return nil }
        guard let end = text.firstIndex(of: "\n") else {
            defer { text = text[text.endIndex...] }
            return text
        }
        defer { text = text[text.index(after: end)...] }
        return text[..<end]
    }

    /// Reads the start of the file only, so that a large program costs no more than a small script.
    public init(url: URL) {
        let file = try? FileHandle(forReadingFrom: url)
        let data = (try? file?.read(upToCount: Self.limit)) ?? Data()
        try? file?.close()
        self.init(text: String(decoding: data, as: UTF8.self))
    }
}
