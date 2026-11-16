import Foundation

public struct CommandHelp: Sendable {
    struct Entry: Encodable {
        let command: String
        let form: String
        let about: String
        let group: String
        let effect: String
        let does: String?
        let needsApp: Bool
        let use: String?
    }

    static let hint = "Run `openspot help` to see each command.\n"

    let nouns: [CommandNoun]

    private var guides: String {
        CommandNoun.listed(nouns.filter { $0.guide != nil }.map(\.name).sorted())
    }

    var text: String {
        CommandGroup.allCases.compactMap { group in
            let lines = nouns.filter { $0.group == group }.flatMap { $0.lines(guides: guides) }
            return lines.isEmpty ? nil : group.rawValue + "\n\n" + lines.map { $0 + "\n" }.joined()
        }.joined(separator: "\n")
    }

    func verbs(of noun: CommandNoun, verb: [String] = []) -> String {
        noun.lines(guides: guides, verb: verb).map { $0 + "\n" }.joined()
    }

    var entries: [Entry] {
        nouns.flatMap { noun in
            noun.shown.map { verb in
                let (effect, does) = verb.rule.act
                return Entry(
                    command: (["openspot", noun.name] + verb.words).joined(separator: " "), form: verb.form,
                    about: verb.about.replacingOccurrences(of: CommandNoun.guides, with: guides), group: noun.group.rawValue,
                    effect: effect, does: does, needsApp: verb.rule.flags.contains(.needsApp), use: verb.rule.use?.rawValue
                )
            }
        }
    }

    func unknown(_ parts: [String]) -> String {
        let first = "openspot cannot do this: \(parts.joined(separator: " "))\n"
        guard let word = parts.first else { return first + Self.hint }
        let rest = Array(parts.dropFirst())
        guard let noun = nouns.first(where: { $0.name == word }) else {
            guard let close = Self.closest(to: word, in: nouns.filter { !$0.shown.isEmpty }.map(\.name)),
                  let noun = nouns.first(where: { $0.name == close })
            else { return first + Self.hint }
            return first + "Did you mean `\(suggestion(noun, rest))`?\n\n" + verbs(of: noun)
        }
        if let verb = noun.verb(of: rest), !verb.words.isEmpty {
            return first + "\n" + verbs(of: noun, verb: verb.words)
        }
        guard let verb = rest.first else { return first + "`openspot \(noun.name)` needs a verb.\n\n" + verbs(of: noun) }
        let close = Self.closest(to: verb, in: noun.shown.compactMap(\.words.first)).map { _ in suggestion(noun, rest) }
        return first + (close.map { "Did you mean `\($0)`?\n" } ?? "") + "\n" + verbs(of: noun)
    }

    private func suggestion(_ noun: CommandNoun, _ rest: [String]) -> String {
        let verbs = noun.shown.compactMap(\.words.first)
        let fixed = rest.first.flatMap { verbs.contains($0) ? $0 : Self.closest(to: $0, in: verbs) }
        let words = fixed.map { [$0] + rest.dropFirst() } ?? rest
        return (["openspot", noun.name] + words).joined(separator: " ")
    }

    static func closest(to word: String, in names: [String]) -> String? {
        guard !word.hasPrefix("-"), word.count >= 2 else { return nil }
        let close = names.filter { name in
            name.count >= 3 && word.count >= 3 && (word.hasPrefix(name) || name.hasPrefix(word))
                || distance(word, name) <= max(1, min(word.count, name.count) / 3)
        }
        return close.min { distance(word, $0) < distance(word, $1) }
    }

    private static func distance(_ one: String, _ other: String) -> Int {
        let one = Array(one), other = Array(other)
        var row = Array(0...other.count)
        for (index, letter) in one.enumerated() {
            var next = [index + 1]
            for (place, match) in other.enumerated() {
                next.append(min(row[place + 1] + 1, next[place] + 1, row[place] + (letter == match ? 0 : 1)))
            }
            row = next
        }
        return row[other.count]
    }
}
