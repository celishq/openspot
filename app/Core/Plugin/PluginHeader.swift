import Foundation

/// The `key=value` comment lines at the top of a script, which say what it is without running it.
public struct PluginHeader: Equatable, Sendable {
    private static let limit = 4096
    private static let marks = ["//", "--", "#"]

    public let block: TextBlock

    /// Reads the comment lines under the first line of a script. The first other line ends them, and a program has none.
    public init(text: String) {
        var lines: [String] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if index == 0, line.hasPrefix("#!") { continue }
            guard let mark = Self.marks.first(where: { line.hasPrefix($0) }) else { break }
            let comment = line.dropFirst(mark.count).trimmingCharacters(in: .whitespaces)
            if !comment.isEmpty { lines.append(comment) }
        }
        block = TextBlock.blocks(in: lines.joined(separator: "\n")).first ?? TextBlock(fields: [])
    }

    /// Reads the start of the file only, so that a large program costs no more than a small script.
    public init(url: URL) {
        let file = try? FileHandle(forReadingFrom: url)
        let data = (try? file?.read(upToCount: Self.limit)) ?? Data()
        try? file?.close()
        self.init(text: String(decoding: data, as: UTF8.self))
    }
}
