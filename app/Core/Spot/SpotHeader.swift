import Foundation

public struct SpotHeader: Equatable, Sendable {
    static let limit = 65_536
    private static let chunk = 4096
    private static let marks = ["//", "--", "#"]

    public let block: TextBlock
    public let isTooLong: Bool
    private let hasEnded: Bool

    public init(text: String) {
        var lines: [String] = []
        var rest = text[...]
        var isFirst = true
        var hasEnded = false
        var end = text.startIndex
        while let line = Self.nextLine(of: &rest) {
            defer { isFirst = false }
            if !(isFirst && line.hasPrefix("#!")) {
                guard let mark = Self.marks.first(where: { line.hasPrefix($0) }) else {
                    hasEnded = rest.startIndex > line.endIndex
                    break
                }
                lines.append(line.dropFirst(mark.count).trimmingCharacters(in: .whitespaces))
            }
            end = rest.startIndex
        }
        self.hasEnded = hasEnded
        isTooLong = text[..<end].utf8.count > Self.limit
        var keys: [TextBlock.Field] = []
        var children: [TextBlock] = []
        for block in TextBlock.blocks(in: lines.joined(separator: "\n")) {
            if HeaderBlock(block: block) != nil {
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
        defer { try? file?.close() }
        var data = Data()
        while data.count <= Self.limit, let chunk = try? file?.read(upToCount: Self.chunk), !chunk.isEmpty {
            data += chunk
            if SpotHeader(text: String(decoding: data, as: UTF8.self)).hasEnded { break }
        }
        self.init(text: String(decoding: data, as: UTF8.self))
    }
}
