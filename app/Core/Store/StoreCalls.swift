import Foundation

struct StoreCalls {
    let places: AppPlaces
    let app: (any RunningApp)?

    private static func catalog(in places: AppPlaces) -> SpotCatalog {
        let config = places.config.read()
        return SpotCatalog(
            published: places.store, folder: places.spots, arrangement: config.arrangement, stores: StoreSource.all(builtIn: places.examples, config: config), lock: places.lock
        )
    }

    private struct PrintedFolder: PrintedRecord {
        let store, name: String
        let found, builtin: Bool

        var blocks: [[(String, String?)]] {
            [[("item", store), ("title", name), ("found", String(found)), ("builtin", builtin ? "true" : nil)]]
        }
    }

    func add(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let expanded = (path as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else { throw SpotError.failed(1, "Give the full path of the folder, such as `~/Spots`.") }
            let said = try StoreSource.add(URL(fileURLWithPath: expanded), to: places.config)
            await app?.spotsChanged()
            return said
        }
    }

    func remove(_ path: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let said = try StoreSource.remove(URL(fileURLWithPath: (path as NSString).expandingTildeInPath), from: places.config)
            await app?.spotsChanged()
            return said
        }
    }

    func folders(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            let stores = StoreSource.all(builtIn: places.examples, config: places.config.read()).filter { !$0.isBuiltIn || $0.exists() }
            return try form.text(of: stores.map { PrintedFolder(store: $0.url.path, name: $0.name, found: $0.exists(), builtin: $0.isBuiltIn) })
        }
    }

    func list(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let before = try places.lock.entries()
            await SpotUpdate(places: places).takeEachWithNoNewPower()
            if try places.lock.entries() != before { await app?.spotsChanged() }
            return try Self.catalog(in: places).text(form)
        }
    }

    func update(_ id: String?, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let said = try await SpotUpdate(places: places).run(id, isConfirmed: isConfirmed)
            await app?.spotsChanged()
            return said
        }
    }

    func revert(_ id: String, isConfirmed: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let said = try await SpotUpdate(places: places).revert(id, isConfirmed: isConfirmed)
            await app?.spotsChanged()
            return said
        }
    }

    func get(_ id: String, isConfirmed: Bool, clash: SpotClash?) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let catalog = Self.catalog(in: places)
            guard let install = try catalog.install(id, in: places) else {
                return "\(catalog.item(id)?.spot.name ?? id) is one of your spots already.\n"
            }
            let said = try await install.run(clash, isConfirmed: isConfirmed)
            await app?.spotsChanged()
            return said
        }
    }

    func open(_ id: String?, search: String?) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning(["store open", id].compactMap { $0 }.joined(separator: " ")) }
        return CommandAnswer.work { [places] in
            if let id {
                let config = places.config.read()
                let sources = StoreSource.all(builtIn: places.examples, config: config)
                let known = Self.catalog(in: places).item(id) != nil || sources.contains { $0.fetch(id) != nil }
                guard known else { throw SpotError.failed(1, "`\(id)` is not a spot of the Store. Run `openspot store list` to see each one.") }
            }
            guard await app.openStore(id, search: search) else { throw SpotError.failed(1, "Openspot did not open the Store.") }
            return ""
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
