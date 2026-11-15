import Foundation

struct KeyCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    func set(app name: String, to key: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            guard let shortcut = Shortcut(text: key) else { throw SpotError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.") }
            try ConfigFile.standard(environment: environment).set(name, to: shortcut.text)
            await app?.configChanged(.keys)
            return ""
        }
    }

    func set(_ act: GlobalKey.Act, of spot: String, to key: String?) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let trigger = try key.map { key in
                guard let trigger = Trigger(text: key) else { throw SpotError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab, or use shake.") }
                return trigger
            }
            try ConfigFile.standard(environment: environment).assign(trigger, to: spot, act: act)
            await app?.configChanged(.keys)
            return ""
        }
    }
}
