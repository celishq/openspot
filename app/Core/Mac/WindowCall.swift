import Foundation

enum WindowCall: NounCall {
    case frame
    case move(WindowMove)
    case app

    static let noun = CommandNoun("window", group: .mac, verbs: [
        CommandVerb("frame", "", "Prints the front window, then the usable area of its screen: x y width height x y width height, from the top left of the main screen.", rule: CallRule(use: .screen, used: "read the place of a window")) { $0.none ? Self.frame : nil },
        CommandVerb("move", "frame...", "Moves the front window to a frame, x y width height. 50%, 1/2 or a number from 0 to 1 is a part of the area, and any other number is points. With more frames, it moves to the frame after the one it holds now.", rule: CallRule(use: .screen, used: "moved a window", inShow: .changes("moves a window"))) { words in
            words.none ? nil : WindowMove(words: words.rest).map(Self.move)
        },
        CommandVerb("app", "", "Prints the app= bundle ID, name= and path= of the app in front of Openspot, or nothing.", rule: ReadSources.rule) { $0.none ? Self.app : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .frame: CommandAnswer.work { [mac = context.mac.windows] in try await Mac.part(mac, "windows").frame().text }
        case .move(let move): CommandAnswer.work { [mac = context.mac.windows] in
            try await Mac.part(mac, "windows").move(move)
            return ""
        }
        case .app: ReadSources.work(in: context) { sources, _ in await sources.app() }
        }
    }
}
