import Foundation

struct RepoDoc {
    struct Fence {
        let language: String
        let text: String
    }

    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    let path: String
    let text: String

    init(_ path: String) throws {
        self.path = path
        text = try String(contentsOf: Self.repo.appendingPathComponent(path), encoding: .utf8)
    }

    static func all() throws -> [RepoDoc] {
        try ["", "app/", "app/Help/"].flatMap { folder in
            try FileManager.default.contentsOfDirectory(atPath: repo.appendingPathComponent(folder).path)
                .filter { $0.hasSuffix(".md") }.sorted().map { try RepoDoc(folder + $0) }
        }
    }

    var folder: URL {
        Self.repo.appendingPathComponent(path).deletingLastPathComponent()
    }

    var prose: String {
        var kept: [String] = []
        var inFence = false
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") { inFence.toggle(); continue }
            if !inFence { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    var fences: [Fence] {
        var found: [Fence] = []
        var language: String?
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            if let open = language {
                if line == "```" {
                    found.append(Fence(language: open, text: lines.map { $0 + "\n" }.joined()))
                    language = nil
                } else {
                    lines.append(line)
                }
            } else if line.hasPrefix("```") {
                language = String(line.dropFirst(3))
                lines = []
            }
        }
        return found
    }

    var headings: [String] {
        prose.components(separatedBy: "\n").filter { $0.hasPrefix("#") && $0.contains("# ") }.map { String($0.drop { $0 == "#" }.dropFirst()) }
    }

    var anchors: Set<String> {
        Set(headings.map(Self.anchor))
    }

    func section(_ heading: String) -> String {
        let lines = prose.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("#") && String($0.drop { $0 == "#" }.dropFirst()) == heading }) else { return "" }
        let level = lines[start].prefix { $0 == "#" }.count
        let rest = lines[(start + 1)...].prefix { line in !(line.hasPrefix("#") && line.contains("# ") && line.prefix { $0 == "#" }.count <= level) }
        return rest.joined(separator: "\n")
    }

    static func anchor(of heading: String) -> String {
        heading.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "_" }.replacingOccurrences(of: " ", with: "-")
    }

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        let expression = try! NSRegularExpression(pattern: pattern)
        let whole = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: whole.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : whole.substring(with: match.range(at: $0)) }
        }
    }

    static func tableRows(in text: String) -> [[String]] {
        let lines = text.components(separatedBy: "\n")
        return lines.indices.filter { index in
            lines[index].hasPrefix("|") && !lines[index].hasPrefix("| -") && index + 1 < lines.count && !lines[index + 1].hasPrefix("| -")
        }.map { index in
            lines[index].split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    static func code(_ cell: String) -> [String] {
        matches("`([^`]+)`", in: cell).map { $0[1] }
    }
}
