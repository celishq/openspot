import Foundation

struct GuideTopic: Equatable, Sendable {
    let slug: String
    let title: String
    let text: String

    var sections: [GuideTopic] {
        Self.all(in: text, level: "## ").map { GuideTopic(slug: slug + "/" + $0.slug, title: $0.title, text: $0.text) }
    }

    static func all(in guide: String, level: String = "# ") -> [GuideTopic] {
        var topics: [GuideTopic] = []
        var lines: [Substring] = []
        var isFenced = false
        func close() {
            guard let head = lines.first else { return }
            let title = String(head.dropFirst(level.count))
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
            topics.append(GuideTopic(slug: slug(of: title), title: title, text: text))
            lines = []
        }
        for line in guide.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```") { isFenced.toggle() }
            if !isFenced, line.hasPrefix(level) {
                close()
                lines = [line]
                continue
            }
            if !lines.isEmpty { lines.append(line) }
        }
        close()
        return topics
    }

    static func found(_ word: String, in topics: [GuideTopic]) -> [GuideTopic] {
        let word = word.lowercased()
        guard !word.contains("-") else { return [] }
        return topics.filter { $0.slug.split(separator: "-").contains { $0 == word || $0 == word + "s" || $0 + "s" == word } }
    }

    private static func slug(of title: String) -> String {
        String(title.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" }.map(Character.init))
            .replacingOccurrences(of: " ", with: "-")
    }
}
