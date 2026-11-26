import Foundation

enum GuideCall: NounCall {
    case map
    case all
    case topic(String)
    case find([String])

    static let noun = CommandNoun("guide", group: .start, verbs: [
        CommandVerb("", "[address | --all | --find <words>...]", "Prints the map of the guide to building a spot: the address and the size of each part. Read it before you write one. An address prints a page, a page/section one section, and a key, a block, a class or a command its row. --find lists each part that holds every word, and --all prints the whole guide.") { words in
            if let first = words.fit?.value("--find") { return GuideCall.find([first] + (words.fit?.rest ?? [])) }
            return switch (words.fit?.has("--all"), words.fit?.rest ?? []) {
            case (false?, []): GuideCall.map
            case (true?, []): GuideCall.all
            case (false?, let rest) where rest.count == 1 && !rest[0].hasPrefix("-"): GuideCall.topic(rest[0])
            default: nil
            }
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let mac = context.mac
        return {
            do {
                let guide = try mac.readGuide()
                let topics = guide.topics
                switch self {
                case .all: return CommandAnswer(output: guide.text)
                case .map: return CommandAnswer(output: guide.map)
                case .find(let words):
                    let found = guide.find(words)
                    guard !found.isEmpty else { return CommandAnswer(errors: "No part of the guide holds \(words.joined(separator: " ")). Run `openspot guide` for the map.\n", code: 1) }
                    let width = (found.map(\.address.count).max() ?? 0) + 4
                    return CommandAnswer(output: found.map { $0.address.padding(toLength: width, withPad: " ", startingAt: 0) + $0.line + "\n" }.joined())
                case .topic(let name):
                    if let topic = guide.topic(name) { return CommandAnswer(output: topic.text) }
                    if let rows = guide.rows(naming: name) { return CommandAnswer(output: rows) }
                    if let section = guide.section(named: name) { return CommandAnswer(output: section.text) }
                    let found = GuideTopic.found(name, in: topics)
                    if found.count == 1 { return CommandAnswer(output: found[0].text) }
                    if !found.isEmpty { return CommandAnswer(output: Self.list(found)) }
                    if let slash = name.firstIndex(of: "/"), let page = guide.topic(String(name[..<slash])) {
                        let slugs = page.sections.map(\.slug)
                        let hint = CommandHelp.closest(to: name.lowercased(), in: slugs).map { "Did you mean `openspot guide \($0)`?" }
                            ?? "Its sections are " + slugs.map { "`openspot guide \($0)`" }.joined(separator: ", ") + "."
                        return CommandAnswer(errors: "The page \(page.slug) has no section \(name[name.index(after: slash)...]). \(hint)\n", code: 2)
                    }
                    let close = CommandHelp.closest(to: name.lowercased(), in: guide.addresses).map { " Did you mean `openspot guide \($0)`?" } ?? ""
                    return CommandAnswer(errors: "The guide has no part \(name).\(close) Run `openspot guide` for the map, or `openspot guide --find \(name)`.\n", code: 2)
                }
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }

    private static func list(_ topics: [GuideTopic]) -> String {
        let width = (topics.map(\.slug.count).max() ?? 0) + 4
        return topics.map { $0.slug.padding(toLength: width, withPad: " ", startingAt: 0) + $0.title + "\n" }.joined()
    }
}
