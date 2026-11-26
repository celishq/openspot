import Foundation

struct SettingCalls {
    let places: AppPlaces
    let caller: String?
    let app: (any RunningApp)?
    let secrets: SecretStore
    var channel: String?
    let mac: Mac

    func get(_ key: String, of spot: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, secrets, channel] in
            let config = places.config.read()
            if let act = GlobalKey.Act(setting: key) {
                return config.keys.first { $0.spot == spot && $0.act == act }.map { $0.trigger.text + "\n" } ?? ""
            }
            if let secret = try secrets.read()[spot]?[key] { return (channel == spot ? secret : FieldValues.hidden) + "\n" }
            return config.setting(key, of: spot).map { $0 + "\n" } ?? ""
        }
    }

    func set(_ key: String, of spot: String, to value: String?) -> CommandAPI.Work {
        CommandAnswer.work { [places, caller, app, secrets] in
            if try secrets.read()[spot]?[key] != nil || Self.isSecret(key, of: spot, in: places) {
                throw SpotError.failed(1, "Openspot keeps `\(key)` of \(spot) as a secret, so only its own form changes it. Open the Settings of \(spot), and press Return on its row.")
            }
            let config = try places.config.change { $0.set(setting: key, of: spot, to: value) }
            await app?.configChanged([ReservedSetting.icon, ReservedSetting.attachment].contains(key) ? .spots([spot]) : .value(spot: spot, caller: caller), to: config)
            return ""
        }
    }

    func remove(_ key: String, of spot: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, caller, app, secrets] in
            if try secrets.read()[spot]?[key] != nil { try secrets.keep(nil, key: key, of: spot) }
            let config = try places.config.change { $0.set(setting: key, of: spot, to: nil) }
            await app?.configChanged(.value(spot: spot, caller: caller), to: config)
            return ""
        }
    }

    func list(of spot: String?, _ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [self] in try form.text(of: try await rows(of: spot)) }
    }

    func rows(of spot: String?) async throws -> [SettingRow] {
        let config = places.config.read()
        return try await rows(of: spot, config: config, scan: spot == ReservedSetting.appSpot ? ScanResult(files: [], refused: []) : places.spots.scan())
    }

    func rows(of spot: String?, config: Config, scan: ScanResult) async throws -> [SettingRow] {
        let isApp = spot == ReservedSetting.appSpot
        var rows: [SettingRow] = []
        if spot == nil || isApp {
            let flags: [AppSetting: Bool?] = [.slow: await app?.slowMotion(nil) ?? nil, .login: mac.login()?.isOn(), .link: mac.link()?.isOn]
            rows += AppSetting.rows(flags.compactMapValues { $0.map(String.init) }.merging([
                .panelKey: (config.panelKey ?? .standard).text,
                .fixKey: (config.fixKey ?? .fix).text,
                .theme: ThemeFolder(config: places.config, builtIn: mac.theme).readInUse()
            ]) { flag, _ in flag })
        }
        if !isApp {
            var scan = scan
            scan.addSettings(in: places.config, read: config, defaults: places.readDefaultArrangement())
            let found = scan.scripts.filter { spot == nil || $0.id == spot }.compactMap(\.rows)
            if let spot, found.isEmpty { throw SpotError.failed(1, "Openspot cannot find \(spot). Turn it on in Spots, then try again.") }
            let kept = try secrets.read()
            rows += found.flatMap { $0.rows(in: config, secrets: kept[$0.spot] ?? [:]) }
        }
        return rows
    }

    func window(of spot: String, _ isWindow: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let config = try places.config.change { $0.arrangement.set(isWindow: isWindow, of: spot) }
            await app?.configChanged(.spots([spot]), to: config)
            return ""
        }
    }

    private static func isSecret(_ key: String, of spot: String, in places: AppPlaces) -> Bool {
        let script = try? places.spots.scan().scripts.first { $0.id == spot }
        return script?.settings.contains { $0.id == key && $0.isSecret } == true
    }

    func change(_ key: String, of spot: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("setting change \(key)") }
        return CommandAnswer.work {
            guard await app.changeSetting(key, of: spot) else { throw SpotError.failed(1, "Openspot cannot find \(spot). Turn it on in Spots, then try again.") }
            return ""
        }
    }
}
