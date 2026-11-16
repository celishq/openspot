import Foundation

public enum AccountCall: NounCall {
    case status(PrintForm)

    static let noun = CommandNoun("account", group: .app, verbs: [
        CommandVerb("show", "[--json]", "Prints the account that signs what you publish as one block: signedIn, npub, handle, since, backedUp and sync. --json prints it as JSON.") { words in
            words.form.map(Self.status)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let account = context.account else { return CommandAnswer.notRunning("account") }
        return CommandAnswer.work {
            switch self {
            case .status(let form): try form.text(of: account.status())
            }
        }
    }
}
