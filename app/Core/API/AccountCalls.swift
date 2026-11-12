import Foundation

/// The calls of `openspot account`, which only the running app answers, so that no other program reads the Keychain.
struct AccountCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    private var store: AccountStore {
        .standard(environment: environment)
    }

    func status(frame: Bool) -> CommandAPI.Work {
        guard app != nil else { return CommandAnswer.notRunning("account") }
        return CommandAnswer.work { [store] in
            let key = try store.key()
            return try AccountStatus(
                signedIn: key != nil,
                npub: key?.npub,
                backedUp: key == nil ? nil : try store.isBackedUp(),
                sync: key == nil || !store.canSync ? nil : try store.isSyncing()
            ).text(frame: frame)
        }
    }

    func open() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("account open") }
        return CommandAnswer.work {
            _ = await app.openAccount()
            return ""
        }
    }

    func sync(_ isOn: Bool) -> CommandAPI.Work {
        guard app != nil else { return CommandAnswer.notRunning("account sync") }
        return CommandAnswer.work { [store] in
            try store.setSyncing(isOn)
            return ""
        }
    }

    func new() -> CommandAPI.Work {
        CommandAnswer.work { [store] in
            _ = try store.keyMadeOnce()
            return ""
        }
    }

    func words() -> CommandAPI.Work {
        CommandAnswer.work { [store, app] in
            guard let words = try store.key()?.words else { throw SpotError.failed(1, "This Mac holds no account words.") }
            guard await app?.allows("show your account words") == true else { throw SpotError.failed(1, "Touch ID didn't pass, so Openspot showed no words.") }
            return words.map { "word=\($0)\n" }.joined()
        }
    }

    func check(_ places: [Int]) -> CommandAPI.Work {
        CommandAnswer.work { [store] in
            guard let key = try store.key(), key.words != nil else { throw SpotError.failed(1, "This Mac holds no account words.") }
            return places.map { place in
                TextBlock(fields: [.init(key: "check", value: String(place))] + AccountFlow.choices(at: place, of: key).map { .init(key: "choice", value: $0) }).text
            }.joined(separator: "\n")
        }
    }

    func checked(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [store] in
            guard let words = try store.key()?.words else { throw SpotError.failed(1, "This Mac holds no account words.") }
            for line in await input().split(whereSeparator: \.isNewline) {
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count == 2, let place = Int(parts[0]), words.indices.contains(place - 1) else { continue }
                guard parts[1].lowercased() == words[place - 1] else { throw SpotError.failed(1, "That isn't word \(place). Look at your words again.") }
            }
            try store.markBackedUp()
            return ""
        }
    }

    func phrase(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [store] in
            let text = await input()
            return await MainActor.run {
                let flow = AccountFlow(store: store, step: .restore)
                flow.phrase = text
                return flow.facts
            }
        }
    }

    func signIn(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        CommandAnswer.work { [store] in
            let text = await input()
            let failure: String? = await MainActor.run {
                let flow = AccountFlow(store: store, step: .restore)
                flow.phrase = text
                guard flow.canSignIn else { return flow.problem ?? "Type all 12 words first." }
                flow.signIn()
                return flow.failure
            }
            if let failure { throw SpotError.failed(1, failure) }
            return ""
        }
    }

    func signOut() -> CommandAPI.Work {
        CommandAnswer.work { [store, app] in
            guard await app?.allows("sign out of your account") == true else { throw SpotError.failed(1, "Touch ID didn't pass, so your account stays.") }
            try store.remove()
            return ""
        }
    }
}
