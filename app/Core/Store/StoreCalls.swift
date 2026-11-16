import Foundation

struct StoreCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    private static func store(in environment: [String: String]) -> SpotStore {
        let config = ConfigFile.standard(environment: environment).read()
        return SpotStore(url: SpotStore.url(environment: environment), folder: SpotsFolder.standard(environment: environment), arrangement: config.arrangement, stores: StoreFolder.all(environment: environment, config: config))
    }

    private struct PrintedFolder: PrintedRecord {
        let store, name: String
        let found, builtin: Bool

        var blocks: [[(String, String?)]] {
            [[("store", store), ("name", name), ("found", String(found)), ("builtin", builtin ? "true" : nil)]]
        }
    }

    func add(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let expanded = (path as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else { throw SpotError.failed(1, "Give the full path of the folder, such as `~/Spots`.") }
            let store = StoreFolder(url: URL(fileURLWithPath: expanded))
            guard store.exists() else { throw SpotError.failed(1, "Openspot cannot find \(store.url.path).") }
            guard !((try? SpotsFolder(url: store.url).scan())?.files ?? []).isEmpty else {
                throw SpotError.failed(1, "\(store.name) has no spot folder, so it cannot be a store. Pick a folder that holds a folder such as weather.spot.")
            }
            _ = try ConfigFile.standard(environment: environment).change { $0.add(store: store) }
            await app?.spotsChanged()
            return "Added the store \(store.name).\n"
        }
    }

    func remove(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let store = StoreFolder(url: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
            let file = ConfigFile.standard(environment: environment)
            guard file.read().stores.contains(store) else {
                throw SpotError.failed(1, "\(store.url.path) is not a store. Run `openspot store folders` to see each one.")
            }
            _ = try file.change { $0.remove(store: store) }
            await app?.spotsChanged()
            return "Removed the store \(store.name).\n"
        }
    }

    func folders(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let stores = StoreFolder.all(environment: environment, config: ConfigFile.standard(environment: environment).read()).filter { !$0.isBuiltIn || $0.exists() }
            return try form.text(of: stores.map { PrintedFolder(store: $0.url.path, name: $0.name, found: $0.exists(), builtin: $0.isBuiltIn) })
        }
    }

    func list(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in try Self.store(in: environment).text(form) }
    }

    func get(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let file = ConfigFile.standard(environment: environment)
            let item = try await Self.store(in: environment).get(id, config: file, environment: environment)
            await app?.spotsChanged()
            return "Added \(item.spot.name).\n"
        }
    }

    func publish(_ id: String, account: Account?, caller: CallerTokens.Caller?) -> CommandAPI.Work {
        guard let app, let account else { return CommandAnswer.notRunning("store publish \(id)") }
        return CommandAnswer.work {
            try account.admit(caller)
            switch await app.publish(id) {
            case .published: return "Published \(id).\n"
            case .unchanged: return "\(id) has no change since its last publish.\n"
            case .needsReadme: throw SpotError.failed(1, "\(id) has no readme.md. Write one beside its script, then publish again.")
            case .notOwn: throw SpotError.failed(1, "`\(id)` is not a spot of your spots folder, so it cannot be published.")
            case .failed: throw SpotError.failed(1, "\(id) was not published. The toast in Openspot says why.")
            }
        }
    }
}
