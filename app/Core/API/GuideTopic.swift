import Foundation

struct GuideTopic: Equatable, Sendable {
    let slug: String
    let title: String
    let text: String

    static func all(in guide: String) -> [GuideTopic] {
        var topics: [GuideTopic] = []
        var lines: [Substring] = []
        var isFenced = false
        func close() {
            guard let head = lines.first else { return }
            let title = String(head.dropFirst(3))
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
            topics.append(GuideTopic(slug: slug(of: title), title: title, text: text))
            lines = []
        }
        for line in guide.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```") { isFenced.toggle() }
            if !isFenced, line.hasPrefix("# ") || line.hasPrefix("## ") {
                close()
                if line.hasPrefix("## ") { lines = [line] }
                continue
            }
            if !lines.isEmpty { lines.append(line) }
        }
        close()
        return topics
    }

    private static func slug(of title: String) -> String {
        String(title.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" }.map(Character.init))
            .replacingOccurrences(of: " ", with: "-")
    }
}
