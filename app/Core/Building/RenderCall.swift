import Foundation

public enum RenderCall: NounCall {
    case sheet(String, view: String?)
    case card(SpotSize, String)
    case spot(id: String, size: SpotSize?, path: String, isLight: Bool = false)
    case panel(String, scene: PanelScene = PanelScene())
    case store(String, place: String?, spot: String?, review: String?)

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
        CommandVerb("panel", "[--arrange] [--search <text>] [--swap <id>] [--hold] <file.png>", "Draws the panel with each installed spot on its grid; with --arrange, Arrange over the screen with the words of --search in its field and the spot of --swap lifted over the last card; with --hold, the grid while ⌘ is held.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            let scene = PanelScene(isArranging: fit.has("--arrange"), search: fit.value("--search"), swap: fit.value("--swap"), isHeld: fit.has("--hold"))
            guard scene.isArranging || (scene.search == nil && scene.swap == nil) else { return nil }
            guard !(scene.isArranging && scene.isHeld) else { return nil }
            return Self.panel(fit.rest[0], scene: scene)
        },
        CommandVerb("store", "[--place <name>] [--spot <id>] [--review <id>] <file.png>", "Draws the window of the Store at My spots, or at the place --place names, such as Openspot, with the page of --spot open, or the review of an install of --review over it.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return Self.store(fit.rest[0], place: fit.value("--place"), spot: fit.value("--spot"), review: fit.value("--review"))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        nil
    }
}
