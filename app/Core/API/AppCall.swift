import Foundation

enum AppCall: NounCall {
    case status(PrintForm)
    case quit

    static let noun = CommandNoun("app", group: .app, verbs: [
        CommandVerb("status", "[--json]", "Prints the state of the app as one block: version, panel-key, fix-key, careful, slow, login, link, update, calls and firstLaunch. --json prints it as JSON.", rule: CallRule(flags: .needsApp)) { words in
            words.form.map(Self.status)
        },
        CommandVerb("quit", "", "Ends the running app.", rule: CallRule(use: .app, used: "quit Openspot", read: .changes("ends Openspot"))) { $0.none ? Self.quit : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = AppCalls(mac: context.mac, environment: context.environment, app: context.app)
        return switch self {
        case .status(let form): calls.status(form)
        case .quit: calls.quit()
        }
    }
}
