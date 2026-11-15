import Foundation

struct AccountCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    private var account: Account {
        Account(store: .standard(environment: environment), allows: { [app] in await app?.allows($0) == true })
    }

    func work(for call: AccountCall, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        switch call {
        case .status(let frame): status(frame: frame)
        case .sync(let isOn): sync(isOn)
        case .new(let handle): new(handle: handle)
        case .words: words()
        case .check(let places): check(places)
        case .checked: checked(input)
        case .phrase: phrase(input)
        case .signIn: signIn(input)
        case .signOut: signOut()
        }
    }

    func status(frame: Bool) -> CommandAPI.Work {
        guard app != nil else { return CommandAnswer.notRunning("account") }
        return CommandAnswer.work { [account] in try account.status().text(frame: frame) }
    }

    func sync(_ isOn: Bool) -> CommandAPI.Work {
        guard app != nil else { return CommandAnswer.notRunning("account sync") }
        return CommandAnswer.work { [account] in
            try account.sync(isOn)
            return ""
        }
    }

    func new(handle: String?) -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            try account.make(handle: handle)
            return ""
        }
    }

    func words() -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            try await account.words().map { "word=\($0)\n" }.joined()
        }
    }

    func check(_ places: [Int]) -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            try zip(places, account.choices(at: places)).map { place, choices in
                TextBlock(fields: [.init(key: "check", value: String(place))] + choices.map { .init(key: "choice", value: $0) }).text
            }.joined(separator: "\n")
        }
    }

    func checked(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            let picks = await input().split(whereSeparator: \.isNewline).compactMap { line -> (place: Int, word: String)? in
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count == 2, let place = Int(parts[0]) else { return nil }
                return (place, parts[1])
            }
            try account.confirm(picks)
            return ""
        }
    }

    func phrase(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work {
            AccountPhrase(await input()).facts
        }
    }

    func signIn(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            try account.signIn(AccountPhrase(await input()))
            return ""
        }
    }

    func signOut() -> CommandAPI.Work {
        CommandAnswer.work { [account] in
            try await account.signOut()
            return ""
        }
    }
}
