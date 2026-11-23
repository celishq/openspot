import Foundation

struct KeyCalls {
    let places: AppPlaces
    let app: (any RunningApp)?

    func set(app name: String, to key: String) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            guard let shortcut = Shortcut(text: key) else { throw SpotError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, a sign, an arrow, space, return or tab.") }
            let config = try places.config.change { $0.set(shortcut, for: name) }
            await app?.configChanged(.keys, to: config)
            return ""
        }
    }

    func set(_ act: GlobalKey.Act, of spot: String, to key: String?) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let trigger = try key.map { key in
                guard let trigger = Trigger(text: key) else { throw SpotError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, a sign, an arrow, space, return or tab, or use shake.") }
                return trigger
            }
            let config = try places.config.change { $0.assign(trigger, to: spot, act: act) }
            await app?.configChanged(.keys, to: config)
            return ""
        }
    }
}
