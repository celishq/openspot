import Foundation

struct SettingCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    func get(_ key: String, of spot: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            ConfigFile.standard(environment: environment).read().setting(key, of: spot).map { $0 + "\n" } ?? ""
        }
    }

    func set(_ key: String, of spot: String, to value: String?) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            try ConfigFile.standard(environment: environment).set(setting: key, of: spot, to: value)
            await app?.configChanged(key == ReservedSetting.icon ? .spots([spot]) : .value(spot: spot, caller: environment["OPENSPOT_ID"]))
            return ""
        }
    }

    func list(frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let list = SpotList(folder: SpotsFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
            return try frame ? list.valuesFrame() : list.values()
        }
    }

    func change(_ key: String, of spot: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("setting change \(key)") }
        return CommandAnswer.work {
            guard await app.changeSetting(key, of: spot) else { throw SpotError.failed(1, "Openspot cannot find \(spot). Turn it on in Spots, then try again.") }
            return ""
        }
    }
}
