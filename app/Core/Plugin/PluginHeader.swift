import Foundation

/// The `key=value` comment lines at the top of a script, which say what it is without running it.
public struct PluginHeader: Equatable, Sendable {
    private static let limit = 4096
    private static let marks = ["//", "--", "#"]

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
            let comment = line.dropFirst(mark.count).trimmingCharacters(in: .whitespaces)
            if !comment.isEmpty { lines.append(comment) }
        }
        block = TextBlock.blocks(in: lines.joined(separator: "\n")).first ?? TextBlock(fields: [])
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
