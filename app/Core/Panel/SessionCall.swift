import Foundation

enum SessionCall: NounCall {
    case open(String)
    case step(Int)

    private static let panel = "moves the panel"

    static let noun = CommandNoun("session", group: .app, verbs: [
        CommandVerb("open", "<id>", "Opens again the session of a timeline entry, as it was: its pages, the page it showed and its text, as a new flow. Opens the panel when it is hidden. It asks the spot again and runs no action.", rule: CallRule(inShow: .changes(panel), flags: .needsApp)) { $0.one.map(Self.open) },
        CommandVerb("back", "[steps]", "Goes back as ⌘[ does: the page before in the flow, then the session before it.", rule: CallRule(inShow: .changes(panel), flags: .needsApp)) { Self.step($0, by: -1) },
        CommandVerb("forward", "[steps]", "Goes forward as ⌘] does: back the other way, and past the newest session to the grid.", rule: CallRule(inShow: .changes(panel), flags: .needsApp)) { Self.step($0, by: 1) },
    ])

    private static func step(_ words: CallWords, by sign: Int) -> SessionCall? {
        guard words.rest.count <= 1 else { return nil }
        guard let steps = words.rest.first.map({ Int($0) }) ?? 1, steps > 0 else { return nil }
        return .step(steps * sign)
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let app = context.app else { return CommandAnswer.notRunning("session") }
        return switch self {
        case .open(let id):
            CommandAnswer.work {
                guard await app.openSession(id) else { throw SpotError.failed(1, "Openspot cannot open the session `\(id)`: the timeline has no such session, or its spot opens in a window. Run `openspot timeline list --spot openspot` to see each one.") }
                return ""
            }
        case .step(let steps):
            CommandAnswer.work {
                guard await app.stepSession(by: steps) else { throw SpotError.failed(1, "There is no session \(steps < 0 ? "before" : "after") this one.") }
                return ""
            }
        }
    }
}
