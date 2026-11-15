import Foundation

enum UpdateCall: NounCall {
    case check
    case install

    static let noun = CommandNoun("update", verbs: [
        CommandVerb("check", "", "Asks for a new version of the app now.", rule: CallRule(use: .app, used: "checked for an update", read: .changes("opens a window"))) { $0.none ? Self.check : nil },
        CommandVerb("install", "", "Restarts the app into the update that it downloaded.", rule: CallRule(use: .app, used: "installed an update", read: .changes("restarts Openspot"))) { $0.none ? Self.install : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = UpdateCalls(app: context.app)
        return switch self {
        case .check: calls.check()
        case .install: calls.install()
        }
    }
}
