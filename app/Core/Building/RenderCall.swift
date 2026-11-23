import Foundation

public enum RenderCall: NounCall {
    case sheet(String, view: String?)
    case card(SpotSize, String)
    case spot(id: String, size: SpotSize?, path: String, isLight: Bool = false)
    case panel(String)
    case store(String)

    private static let rule = CallRule(flags: .ownProcess)

    static let noun = CommandNoun("render", group: .build, verbs: [
        CommandVerb("sheet", "[--view file] <file.png>", "Draws the sheet on stdin to a picture, with its view from a Swift file.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 1, !fit.rest[0].hasPrefix("-") else { return nil }
            return Self.sheet(fit.rest[0], view: fit.value("--view"))
        },
        CommandVerb("card", "<size> <file.png>", "Draws the card of the sheet on stdin at a size, such as wide, to a picture.", rule: rule) { words in
            guard words.rest.count == 2, let size = SpotSize(name: words.rest[0]) else { return nil }
            return Self.card(size, words.rest[1])
        },
        CommandVerb("spot", "<id> [--card <size>] [--light] <file.png>", "Draws the sheet of an installed spot, or its card at a size, dark or light.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 2 else { return nil }
            let size = fit.value("--card").map { SpotSize(name: $0) }
            guard size != .some(nil) else { return nil }
            return Self.spot(id: fit.rest[0], size: size ?? nil, path: fit.rest[1], isLight: fit.has("--light"))
        },
        CommandVerb("panel", "<file.png>", "Draws the panel with each installed spot on its grid.", rule: rule) { $0.one.map(Self.panel) },
        CommandVerb("store", "<file.png>", "Draws the window of the Store with each spot as its card.", rule: rule) { $0.one.map(Self.store) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        nil
    }
}
