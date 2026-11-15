import Foundation

struct SettingCalls {
    let environment: [String: String]
    let caller: String?
    let app: (any RunningApp)?
    let secrets: SecretStore

    func get(_ key: String, of spot: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, secrets] in
            if try secrets.read()[spot]?[key] != nil { return FieldValues.hidden + "\n" }
            return ConfigFile.standard(environment: environment).read().setting(key, of: spot).map { $0 + "\n" } ?? ""
        }
    }

    func set(_ key: String, of spot: String, to value: String?) -> CommandAPI.Work {
        CommandAnswer.work { [environment, caller, app, secrets] in
            if try secrets.read()[spot]?[key] != nil || Self.isSecret(key, of: spot, in: environment) {
                throw SpotError.failed(1, "Openspot keeps `\(key)` of \(spot) as a secret, so only its own form changes it. Open the Settings of \(spot), and press Return on its row.")
            }
            let config = try ConfigFile.standard(environment: environment).change { $0.set(setting: key, of: spot, to: value) }
            await app?.configChanged(key == ReservedSetting.icon ? .spots([spot]) : .value(spot: spot, caller: caller), to: config)
            return ""
        }
    }

    func list(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [environment, secrets] in
            let list = SpotList(folder: SpotsFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
            return try list.values(form, secrets: secrets.read())
        }
    }

    private static func isSecret(_ key: String, of spot: String, in environment: [String: String]) -> Bool {
        let script = try? SpotsFolder.standard(environment: environment).scan().scripts.first { $0.id == spot }
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
