import Foundation

public enum RenderCall: NounCall {
    case sheet(String, view: String?)
    case card(SpotSize, String)
    case spot(id: String, size: SpotSize?, path: String)
    case panel(String)
    case store(String)

    private static let rule = CallRule(flags: .ownProcess)

    static let noun = CommandNoun("render", verbs: [
        CommandVerb("", "[--view file] <file.png>", "Draws the sheet on stdin to a picture, with its view from a Swift file.", rule: rule) { words in
            switch words.rest.count {
            case 1 where !words.rest[0].hasPrefix("-"): Self.sheet(words.rest[0], view: nil)
            case 3 where words.rest[0] == "--view": Self.sheet(words.rest[2], view: words.rest[1])
            default: nil
            }
        },
        CommandVerb("--card", "<size> <file.png>", "Draws its card at a size, such as wide, to a picture.", rule: rule) { words in
            guard words.rest.count == 2, let size = SpotSize(name: words.rest[0]) else { return nil }
            return Self.card(size, words.rest[1])
        },
        CommandVerb("--spot", "<id> [--card <size>] <file.png>", "Draws the sheet of an installed spot, or its card at a size.", rule: rule) { words in
            let rest = words.rest
            if rest.count == 2 { return Self.spot(id: rest[0], size: nil, path: rest[1]) }
            guard rest.count == 4, rest[1] == "--card", let size = SpotSize(name: rest[2]) else { return nil }
            return Self.spot(id: rest[0], size: size, path: rest[3])
        },
        CommandVerb("--panel", "<file.png>", "Draws the panel with each installed spot on its grid.", rule: rule) { $0.one.map(Self.panel) },
        CommandVerb("--store", "<file.png>", "Draws the window of the Store with each spot as its card.", rule: rule) { $0.one.map(Self.store) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        nil
    }
}
