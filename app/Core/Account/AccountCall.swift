import Foundation

public enum AccountCall: NounCall {
    case status(PrintForm)
    case sync(Bool)
    case new(String?)
    case words
    case checked
    case phrase
    case signIn
    case signOut

    private static func key(_ act: String? = nil, input: Bool = false) -> CallRule {
        CallRule(use: .account, used: "reached your account key", read: act.map(CallRule.Read.changes) ?? .free, flags: input ? [.reachesKey, .readsInput] : .reachesKey)
    }

    private static let account = "changes your account"

    static let noun = CommandNoun("account", verbs: [
        CommandVerb("", "[--frame]", "Prints the account that signs what you publish as JSON: signedIn, npub, handle, since, backedUp and sync. --frame prints them as one block.") { words in
            words.form.map(Self.status)
        },
        CommandVerb("new", "[handle]", "Makes an account key, with that handle, when the Mac holds none. The calls from here to sign-out answer only Openspot's Account spot.", rule: key("makes an account")) { words in
            let handle = words.rest.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return Self.new(handle.isEmpty ? nil : handle)
        },
        CommandVerb("words", "", "Prints the 12 words, after Touch ID.", rule: key()) { $0.none ? Self.words : nil },
        CommandVerb("checked", "", "Takes a place and a word on each line of stdin, for two places or more, and marks the words backed up when all are right. It says only that the set is right or wrong.", rule: key(account, input: true)) { $0.none ? Self.checked : nil },
        CommandVerb("phrase", "", "Reads a phrase on stdin, and prints its counter, its unknown words, a completion, a problem or the account it opens.", rule: key(input: true)) { $0.none ? Self.phrase : nil },
        CommandVerb("sign-in", "", "Keeps the key of the 12 words or the nsec on stdin, after Touch ID.", rule: key(account, input: true)) { $0.none ? Self.signIn : nil },
        CommandVerb("sign-out", "", "Removes the account key, after Touch ID.", rule: key(account)) { $0.none ? Self.signOut : nil },
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
        case .words: "account words"
        case .checked: "account checked"
        case .phrase: "account phrase"
        case .signIn: "account sign-in"
        case .signOut: "account sign-out"
        }
    }

    var reachesKey: Bool {
        if case .status = self { false } else { true }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        AccountCalls(account: context.account, caller: context.keyCaller).work(for: self, input: context.input)
    }
}
