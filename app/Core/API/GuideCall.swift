import Foundation

enum GuideCall: NounCall {
    case text
    case topics
    case topic(String)

    static let noun = CommandNoun("guide", group: .start, verbs: [
        CommandVerb("", "[topic | --topics]", "Prints the guide to building a spot. Read it before you write one. A topic prints one part of it, and --topics lists them.") { words in
            switch words.rest {
            case []: Self.text
            case ["--topics"]: Self.topics
            case let rest where rest.count == 1 && !rest[0].hasPrefix("-"): Self.topic(rest[0])
            default: nil
            }
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let guide = context.mac.guide
        return {
            do {
                guard let guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
                let text = try String(contentsOf: guide, encoding: .utf8)
                switch self {
                case .text: return CommandAnswer(output: text)
                case .topics:
                    let topics = GuideTopic.all(in: text)
                    let width = (topics.map(\.slug.count).max() ?? 0) + 4
                    return CommandAnswer(output: topics.map { $0.slug.padding(toLength: width, withPad: " ", startingAt: 0) + $0.title + "\n" }.joined())
                case .topic(let name):
                    let topics = GuideTopic.all(in: text)
                    if let topic = topics.first(where: { $0.slug == name.lowercased() || $0.title.lowercased() == name.lowercased() }) { return CommandAnswer(output: topic.text) }
                    let close = CommandHelp.closest(to: name.lowercased(), in: topics.map(\.slug)).map { " Did you mean `openspot guide \($0)`?" } ?? ""
                    return CommandAnswer(errors: "The guide has no topic \(name).\(close) Run `openspot guide --topics` to see each topic.\n", code: 2)
                }
            } catch {
                return CommandAnswer(failure: error)
            }
        }
    }
}
