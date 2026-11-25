import Foundation

public enum AccountCall: NounCall {
    case status(PrintForm)
    case make(handle: String?)
    case signOut
    case sync(Bool)

    private static let rule = CallRule(use: .account, used: "changed your account", inShow: .changes("changes your account"), flags: .reachesKey)

    static let noun = CommandNoun("account", group: .app, verbs: [
        CommandVerb("show", "[--json]", "Prints the account that signs what you publish as one block: signedIn, npub, handle, since, backedUp and sync. --json prints it as JSON.") { words in
            words.form.map(Self.status)
        },
        CommandVerb("new", "[<handle>]", "Makes the key that signs what you publish, named by the handle, then prints the account. Only Openspot's own spots can run it.", rule: rule) { words in
            words.rest.count <= 1 ? Self.make(handle: words.rest.first) : nil
        },
        CommandVerb("sign-out", "", "Removes the key from this Mac, and from iCloud Keychain when it is kept there, after Touch ID or your password. Only Openspot's own spots can run it.", rule: rule) { words in
            words.none ? Self.signOut : nil
        },
        CommandVerb("sync", "on|off", "Keeps the key in iCloud Keychain, or only on this Mac, after Touch ID or your password, then prints the account. Only Openspot's own spots can run it.", rule: rule) { words in
            words.one.flatMap { ["on": true, "off": false][$0] }.map(Self.sync)
        }
    ])

    private var verb: String {
        switch self {
        case .status: "show"
        case .make: "new"
        case .signOut: "sign-out"
        case .sync: "sync"
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let account = context.account else { return CommandAnswer.notRunning("account \(verb)") }
        let caller = context.caller
        return CommandAnswer.work {
            switch self {
            case .status(let form):
                return try form.text(of: account.status())
            case .make(let handle):
                try account.admit(caller)
                try account.make(handle: handle)
            case .signOut:
                try account.admit(caller)
                try await account.signOut()
            case .sync(let isOn):
                try account.admit(caller)
                try await account.sync(isOn)
            }
            return try PrintForm.frame.text(of: account.status())
        }
    }
}
