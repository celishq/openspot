import Foundation

struct Guide: Sendable {
    let text: String
    let topics: [GuideTopic]

    init(text: String, pages: [String: String]) {
        let text = text.replacingOccurrences(of: #"\[([^\]\n]+)\]\(#([^)\s]+)\)"#, with: "$1 (`openspot guide $2`)", options: .regularExpression)
        self.text = text
        topics = GuideTopic.all(in: text) + pages.sorted { $0.key < $1.key }.map { name, page in
            let head = page.split(separator: "\n").first.map { String($0.drop { $0 == "#" || $0 == " " }) } ?? name
            return GuideTopic(slug: name, title: head, text: page)
        }
    }

    func topic(_ name: String) -> GuideTopic? {
        let name = name.lowercased()
        guard let slash = name.firstIndex(of: "/") else { return topics.first { $0.slug == name || $0.title.lowercased() == name } }
        return topic(String(name[..<slash]))?.sections.first { $0.slug == name }
    }

    func rows(naming word: String) -> String? {
        let word = Self.term(word)
        let blocks = topics.flatMap { $0.sections.isEmpty ? [$0] : $0.sections }.flatMap { part in
            Self.tables(in: part.text).compactMap { table -> String? in
                let rows = table.dropFirst(2).filter { Self.terms(of: $0).contains(word) }
                guard table.count > 2, !rows.isEmpty else { return nil }
                return (table.prefix(2) + rows).joined(separator: "\n") + "\nFrom `openspot guide \(part.slug)`.\n"
            }
        }
        return blocks.isEmpty ? nil : blocks.joined(separator: "\n")
    }

    func section(named word: String) -> GuideTopic? {
        let word = Self.term(word)
        return topics.flatMap(\.sections).first { $0.slug.split(separator: "/").last.map(String.init) == word }
    }

    private static func term(_ text: String) -> String {
        String(text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]")).prefix { $0 != "=" })
    }

    private static func terms(of row: String) -> [String] {
        let cell = row.split(separator: "|", omittingEmptySubsequences: false).dropFirst().first.map(String.init) ?? ""
        return cell.split(separator: "`", omittingEmptySubsequences: false).enumerated().filter { $0.offset % 2 == 1 }.map { term(String($0.element)) }
    }

    private static func tables(in text: String) -> [[String]] {
        var tables: [[String]] = []
        var table: [String] = []
        var isFenced = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("```") { isFenced.toggle() }
            if !isFenced, line.hasPrefix("|") {
                table.append(line)
            } else if !table.isEmpty {
                tables.append(table)
                table = []
            }
        }
        if !table.isEmpty { tables.append(table) }
        return tables
    }

    var addresses: [String] {
        topics.flatMap { [$0.slug] + $0.sections.map(\.slug) }
    }
}
