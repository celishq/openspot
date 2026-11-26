import Foundation

enum AppCall: NounCall {
    case status(PrintForm)
    case quit
    case restart
    case settings(at: String?)

    static let noun = CommandNoun("app", group: .app, verbs: [
        CommandVerb("status", "[--json]", "Prints the state of the app as one block: version, panel-key, fix-key, slow, login, link, update, calls and firstLaunch. --json prints it as JSON.", rule: CallRule(flags: .needsApp)) { words in
            words.form.map(Self.status)
        },
        CommandVerb("quit", "", "Ends the running app.", rule: CallRule(use: .app, used: "quit Openspot", inShow: .changes("ends Openspot"))) { $0.none ? Self.quit : nil },
        CommandVerb("settings", "[--at <where>]", "Opens the Settings window, at a place when one is given: access, access/<id>, spot/<id>, row/<spot>/<key>, keys, look, account, general, developer or search/<words>.", rule: CallRule(inShow: .changes("opens a window"), flags: .needsApp)) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            return Self.settings(at: fit.value("--at"))
        },
        CommandVerb("restart", "", "Ends the running app and starts it again. A guided grant at a step that needs the start, such as Screen Recording, opens again at that step.", rule: CallRule(use: .app, used: "restarted Openspot", inShow: .changes("restarts Openspot"), flags: .needsApp)) { $0.none ? Self.restart : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = AppCalls(mac: context.mac, places: context.places, app: context.app)
        return switch self {
        case .status(let form): calls.status(form)
        case .quit: calls.quit()
        case .restart: calls.restart()
        case .settings(let place): calls.settings(at: place)
        }
    }
}
