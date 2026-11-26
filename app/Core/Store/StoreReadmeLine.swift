import Foundation

public enum StoreReadmeLine: Equatable, Sendable {
    case heading(level: Int, text: String)
    case text(AttributedString)
    case item(marker: String, text: AttributedString)
    case quote(AttributedString)
    case code(String)
    case media(path: String, caption: String)

    private enum Open {
        case none, text, item, quote, code
    }

    static func paragraphs(_ lines: [String]) -> [StoreReadmeLine] {
        var blocks: [(kind: Open, marker: String, text: String)] = []
        var open = Open.none
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if open == .code {
                if trimmed.hasPrefix("```") {
                    open = .none
                } else if let last = blocks.popLast() {
                    blocks.append((.code, "", last.text.isEmpty ? line : "\(last.text)\n\(line)"))
                }
                continue
            }
            if trimmed.hasPrefix("```") {
                blocks.append((.code, "", ""))
                open = .code
            } else if trimmed.isEmpty {
                open = .none
            } else if trimmed.hasPrefix("#") || SpotReadme.media(in: trimmed) != nil {
                blocks.append((.none, "", trimmed))
                open = .none
            } else if let marker = marker(of: trimmed) {
                blocks.append((.item, marker.shown, String(trimmed.dropFirst(marker.length))))
                open = .item
            } else if trimmed.hasPrefix(">") {
                let words = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if open == .quote, let last = blocks.popLast() {
                    blocks.append((.quote, "", "\(last.text) \(words)"))
                } else {
                    blocks.append((.quote, "", words))
                }
                open = .quote
            } else if open == .text || open == .item, let last = blocks.popLast() {
                blocks.append((last.kind, last.marker, "\(last.text) \(trimmed)"))
            } else {
                blocks.append((.text, "", trimmed))
                open = .text
            }
        }
        return blocks.map { block in
            switch block.kind {
            case .code: .code(block.text)
            case .item: .item(marker: block.marker, text: inline(block.text))
            case .quote: .quote(inline(block.text))
            case .text: .text(inline(block.text))
            case .none: single(block.text)
            }
        }
    }

    private static func single(_ line: String) -> StoreReadmeLine {
        if let media = SpotReadme.media(in: line) { return .media(path: media.source, caption: media.caption) }
        let level = line.prefix { $0 == "#" }.count
        return .heading(level: level, text: line.dropFirst(level).trimmingCharacters(in: .whitespaces))
    }

    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var shown = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        let code = shown.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }.map { ($0.range, $0.attributes) }
        for (range, attributes) in code.reversed() {
            let joined = String(shown[range].characters).replacingOccurrences(of: " ", with: "\u{00A0}").replacingOccurrences(of: "-", with: "-\u{2060}")
            shown.replaceSubrange(range, with: AttributedString(joined, attributes: attributes))
        }
        return shown
    }

    private static func marker(of line: String) -> (shown: String, length: Int)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") { return ("•", 2) }
        guard let found = line.range(of: #"^\d+\. "#, options: .regularExpression) else { return nil }
        return (line[found].trimmingCharacters(in: .whitespaces), line.distance(from: found.lowerBound, to: found.upperBound))
    }
}
