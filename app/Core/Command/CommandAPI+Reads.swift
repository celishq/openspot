import Foundation

extension CommandAPI {
    func spotList() async -> SpotList {
        let config = places.config.read()
        var list = SpotList(folder: places.spots, config: config)
        (list.statuses, list.apps) = await access.read(from: mac, browsers: config.browsers)
        list.lastUses = runs?.usage.lastUses ?? StatsLog.readLastUses(in: places.stats)
        list.refused = Stats(days: await StatsLog.days(StatsLog.keptDays, runs: runs, stats: places.stats), spot: nil).refused
        list.allowed = (try? places.lock.entries()) ?? []
        return list
    }

    func accessList() async throws -> (list: AccessList, apps: [TextBlock]) {
        let list = await spotList()
        return (AccessList(statuses: list.statuses, standings: try list.loaded()), list.apps)
    }

    func settingRows() async throws -> [SettingRow] {
        try await settingCalls.rows(of: nil)
    }

    func answer(_ call: any NounCall, as name: String) async -> CommandAnswer {
        let request = CommandRequest(arguments: name.split(separator: " ").map(String.init), folder: places.config.url.deletingLastPathComponent().path, isPiped: false)
        guard let work = work(for: CommandLineCall(name: name, call: call), request: request, input: { "" }) else {
            return CommandAnswer(errors: "openspot cannot do this: \(name)\n", code: 2)
        }
        return await work()
    }

    func settingsFacts() async -> SettingsFacts {
        let list = await spotList()
        let loaded = try? list.loaded()
        let rows = (try? await settingCalls.rows(of: nil, config: list.config, scan: list.scan.get())) ?? []
        let looks = ThemeCall.listed(ThemeFolder(config: places.config, builtIn: mac.theme))
        let account = try? (account ?? Account(store: places.account, allows: { _ in false })).status()
        return SettingsFacts(
            accesses: loaded.map { AccessList(statuses: list.statuses, standings: $0).entries } ?? [], loaded: loaded ?? [],
            rows: rows, looks: looks, account: account
        )
    }

    private var settingCalls: SettingCalls {
        SettingCalls(places: places, caller: nil, app: app, secrets: places.secrets, channel: nil, mac: mac)
    }
}
