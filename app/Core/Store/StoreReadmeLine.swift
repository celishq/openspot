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
}
