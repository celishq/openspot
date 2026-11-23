import Foundation

enum UpdateCall: NounCall {
    case check
    case install

    static let noun = CommandNoun("update", group: .app, verbs: [
        CommandVerb("check", "", "Asks for a new version of the app now.", rule: CallRule(use: .app, used: "checked for an update", inShow: .changes("opens a window"), flags: .needsApp)) { $0.none ? Self.check : nil },
        CommandVerb("install", "", "Restarts the app into the update that it downloaded.", rule: CallRule(use: .app, used: "installed an update", inShow: .changes("restarts Openspot"), flags: .needsApp)) { $0.none ? Self.install : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = UpdateCalls(app: context.app)
        return switch self {
        case .check: calls.check()
        case .install: calls.install()
        }
    }
}
