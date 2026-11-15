import Foundation

public enum AccountCall: NounCall {
    case status(PrintForm)
    case sync(Bool)
    case new(String?)
    case signOut

    private static func key(_ act: String) -> CallRule {
        CallRule(use: .account, used: "reached your account key", read: .changes(act), flags: .reachesKey)
    }

    static let noun = CommandNoun("account", verbs: [
        CommandVerb("", "[--frame]", "Prints the account that signs what you publish as JSON: signedIn, npub, handle, since, backedUp and sync. --frame prints them as one block.") { words in
            words.form.map(Self.status)
        },
        CommandVerb("new", "[handle]", "Makes an account key, with that handle, when the Mac holds none. It, sign-out and sync answer only a spot that ships inside Openspot and names the account use.", rule: key("makes an account")) { words in
            let handle = words.rest.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return Self.new(handle.isEmpty ? nil : handle)
        },
        CommandVerb("sign-out", "", "Removes the account key, after Touch ID.", rule: key("changes your account")) { $0.none ? Self.signOut : nil },
        CommandVerb("sync", "on|off", "Keeps your account in iCloud Keychain, or on this Mac only, after Touch ID.", rule: key("changes where your account is kept")) { words in
            switch words.one {
            case "on": Self.sync(true)
            case "off": Self.sync(false)
            default: nil
            }
        }
    ])

    var name: String {
        switch self {
        case .status: "account"
        case .sync: "account sync"
        case .new: "account new"
        case .signOut: "account sign-out"
        }
    }

    var reachesKey: Bool {
        if case .status = self { false } else { true }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        AccountCalls(account: context.account, caller: context.keyCaller).work(for: self)
    }
}
