import Foundation

struct AccountCalls {
    let account: Account?
    let caller: CallerTokens.Caller?

    func work(for call: AccountCall) -> CommandAPI.Work {
        guard let account else { return CommandAnswer.notRunning(call.name) }
        return CommandAnswer.work { [caller] in
            if call.reachesKey { try account.admit(caller) }
            switch call {
            case .status(let form):
                return try form.text(of: account.status())
            case .sync(let isOn):
                try await account.sync(isOn)
            case .new(let handle):
                try account.make(handle: handle)
            case .signOut:
                try await account.signOut()
            }
            return ""
        }
    }
}
