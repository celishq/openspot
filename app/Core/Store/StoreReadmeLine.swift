import Foundation

public enum StoreReadmeLine: Equatable, Sendable {
    case heading(String)
    case text(AttributedString)
    case media(path: String, caption: String)

    init(_ line: String) {
        if line.hasPrefix("#") {
            self = .heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
        } else if let media = SpotReadme.media(in: line) {
            self = .media(path: media.source, caption: media.caption)
        } else {
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            self = .text((try? AttributedString(markdown: line, options: options)) ?? AttributedString(line))
        }
    }

    static func paragraphs(_ lines: [String]) -> [StoreReadmeLine] {
        var joined: [String] = []
        var isOpen = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isPlain = !trimmed.isEmpty && !trimmed.hasPrefix("#") && SpotReadme.media(in: trimmed) == nil && !startsItem(trimmed)
            if isPlain, isOpen, let last = joined.popLast() {
                joined.append("\(last) \(trimmed)")
            } else if !trimmed.isEmpty {
                joined.append(line)
            }
            isOpen = isPlain || startsItem(trimmed)
        }
        return joined.map(StoreReadmeLine.init)
    }

    private static func startsItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil
    }
}
