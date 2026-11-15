import Foundation

struct AccountCalls {
    let account: Account?
    let caller: CallerTokens.Caller?

    func work(for call: AccountCall, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        guard let account else { return CommandAnswer.notRunning(call.name) }
        return CommandAnswer.work { [caller] in
            if call.reachesKey { try account.admit(caller) }
            switch call {
            case .status(let frame):
                return try account.status().text(frame: frame)
            case .sync(let isOn):
                try await account.sync(isOn)
            case .new(let handle):
                try account.make(handle: handle)
            case .words:
                return try await account.words().map { "word=\($0)\n" }.joined()
            case .checked:
                try await account.confirm(Self.picks(in: await input()))
            case .phrase:
                return AccountPhrase(await input()).facts
            case .signIn:
                try await account.signIn(AccountPhrase(await input()))
            case .signOut:
                try await account.signOut()
            }
            return ""
        }
    }

    private static func picks(in text: String) -> [(place: Int, word: String)] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count == 2, let place = Int(parts[0]) else { return nil }
            return (place, parts[1])
        }
    }
}
