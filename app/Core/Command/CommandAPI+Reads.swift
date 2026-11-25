import Foundation

extension CommandAPI {
    func spotList() async -> SpotList {
        let config = places.config.read()
        let statuses = await access.read(from: mac, browsers: config.browsers).statuses
        let last = runs?.usage.lastUses ?? StatsLog.readLastUses(in: places.stats)
        let refused = Stats(days: await StatsLog.days(StatsLog.keptDays, runs: runs, stats: places.stats), spot: nil).refused
        return SpotList(folder: places.folder(config), config: config, statuses: statuses, lastUses: last, refused: refused, allowed: (try? places.lock.entries()) ?? [])
    }

    func accessList() async throws -> (list: AccessList, apps: [TextBlock]) {
        let config = places.config.read()
        let (statuses, apps) = await access.read(from: mac, browsers: config.browsers)
        let last = runs?.usage.lastUses ?? StatsLog.readLastUses(in: places.stats)
        let spots = try places.folder(config).scan().scripts.map { spot in
            (id: spot.id, access: SpotAccess(spot, written: KeptCalls.shared.read(spot), made: Array((last[spot.id] ?? [:]).keys)))
        }
        return (AccessList(statuses: statuses, spots: spots), apps)
    }

    func settingRows() async throws -> [SettingRow] {
        try await SettingCalls(places: places, caller: nil, app: app, secrets: places.secrets, channel: nil, mac: mac).rows(of: nil)
    }

    public func answer(_ arguments: [String]) async -> CommandAnswer {
        let request = CommandRequest(arguments: arguments, folder: places.config.url.deletingLastPathComponent().path, isPiped: false)
        guard let work = work(for: request, input: { "" }) else {
            return CommandAnswer(errors: "openspot cannot do this: \(arguments.joined(separator: " "))\n", code: 2)
        }
        return await work()
    }

    func settingsFacts() async -> SettingsFacts {
        let accesses = try? await accessList().list
        let spots = await spotList()
        let rows = (try? await settingRows()) ?? []
        let looks = ThemeCall.listed(ThemeFolder(config: places.config, builtIn: mac.theme))
        let account = try? (account ?? Account(store: places.account, allows: { _ in false })).status()
        return SettingsFacts(accesses: accesses, loaded: (try? spots.loadedRecords()) ?? [], core: spots.coreRecords(), rows: rows, looks: looks, account: account)
    }
}
