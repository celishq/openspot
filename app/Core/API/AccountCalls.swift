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
}
