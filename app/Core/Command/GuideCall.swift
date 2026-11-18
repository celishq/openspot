import Foundation

enum GuideCall: NounCall {
    case text
    case topics
    case topic(String)

    static let noun = CommandNoun("guide", group: .start, verbs: [
        CommandVerb("", "[topic | --topics]", "Prints the guide to building a spot. Read it before you write one. A topic prints one part of it, and --topics lists them.") { words in
            switch (words.fit?.has("--topics"), words.fit?.rest ?? []) {
            case (false?, []): Self.text
            case (true?, []): Self.topics
            case (false?, let rest) where rest.count == 1 && !rest[0].hasPrefix("-"): Self.topic(rest[0])
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
                case .text: return CommandAnswer(output: guide.text)
                case .topics:
                    return CommandAnswer(output: Self.list(topics))
                case .topic(let name):
                    if let topic = guide.topic(name) { return CommandAnswer(output: topic.text) }
                    let found = GuideTopic.found(name, in: topics)
                    if found.count == 1 { return CommandAnswer(output: found[0].text) }
                    if !found.isEmpty { return CommandAnswer(output: Self.list(found)) }
                    let close = CommandHelp.closest(to: name.lowercased(), in: topics.map(\.slug)).map { " Did you mean `openspot guide \($0)`?" } ?? ""
                    return CommandAnswer(errors: "The guide has no topic \(name).\(close) Run `openspot guide --topics` to see each topic.\n", code: 2)
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
