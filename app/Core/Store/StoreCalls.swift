import Foundation

struct StoreCalls {
    let places: AppPlaces
    let app: (any RunningApp)?

    private static func catalog(in places: AppPlaces) -> SpotCatalog {
        let config = places.config.read()
        return SpotCatalog(published: places.store, folder: places.folder(config), arrangement: config.arrangement, stores: Store.all(builtIn: places.examples, config: config))
    }

    private struct PrintedFolder: PrintedRecord {
        let store, name: String
        let found, builtin: Bool

        var blocks: [[(String, String?)]] {
            [[("store", store), ("name", name), ("found", String(found)), ("builtin", builtin ? "true" : nil)]]
        }
    }

    func add(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let expanded = (path as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else { throw SpotError.failed(1, "Give the full path of the folder, such as `~/Spots`.") }
            let store = Store(url: URL(fileURLWithPath: expanded))
            guard store.exists() else { throw SpotError.failed(1, "Openspot cannot find \(store.url.path).") }
            let count = ((try? SpotsFolder(url: store.url).scan())?.files ?? []).count
            guard count > 0 else {
                throw SpotError.failed(1, "\(store.name) has no spot folder, so it cannot be a store. Pick a folder that holds a folder such as weather.spot.")
            }
            _ = try places.config.change { $0.add(store: store) }
            await app?.spotsChanged()
            return "Added the store \(store.name) with \(count) \(count == 1 ? "spot" : "spots").\n"
        }
    }

    func remove(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let store = Store(url: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
            let file = places.config
            guard file.read().stores.contains(store) else {
                throw SpotError.failed(1, "\(store.url.path) is not a store. Run `openspot store folders` to see each one.")
            }
            _ = try file.change { $0.remove(store: store) }
            await app?.spotsChanged()
            return "Removed the store \(store.name).\n"
        }
    }

    func folders(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            let stores = Store.all(builtIn: places.examples, config: places.config.read()).filter { !$0.isBuiltIn || $0.exists() }
            return try form.text(of: stores.map { PrintedFolder(store: $0.url.path, name: $0.name, found: $0.exists(), builtin: $0.isBuiltIn) })
        }
    }

    func list(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [places] in try Self.catalog(in: places).text(form) }
    }

    func get(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let file = places.config
            let item = try await Self.catalog(in: places).get(id, config: file, lock: places.lock)
            await app?.spotsChanged()
            return "Added \(item.spot.name).\n"
        }
    }

    func publish(_ id: String, account: Account?, caller: Spot?) -> CommandAPI.Work {
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
