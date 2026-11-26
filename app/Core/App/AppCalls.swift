import Foundation

struct AppCalls {
    let mac: Mac
    let places: AppPlaces
    let app: (any RunningApp)?

    func status(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [mac, places, app] in
            let config = places.config.read()
            let running = await app?.status()
            let slow = await app?.slowMotion(nil) ?? nil
            return try form.text(of: AppStatus(
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                panelKey: (config.panelKey ?? .standard).text,
                fixKey: (config.fixKey ?? .fix).text,
                slow: slow,
                login: mac.login()?.isOn(),
                link: mac.link()?.isOn,
                update: running?.update,
                calls: running?.calls,
                firstLaunch: running?.isFirstLaunch
            ))
        }
    }

    func login(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let login = mac.login() else { throw SpotError.failed(1, "This copy of Openspot cannot open at login. Move it to Applications, then try again.") }
            try login.set(isOn)
            return ""
        }
    }

    func link(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let link = mac.link() else { throw SpotError.failed(1, "This copy of Openspot cannot put openspot in Terminal.") }
            try link.set(isOn)
            return ""
        }
    }

    func slow(_ isOn: Bool) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("setting set --spot openspot slow") }
        return CommandAnswer.work {
            _ = await app.slowMotion(isOn)
            return ""
        }
    }

    func quit() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("app quit") }
        return {
            await app.quit()
            return CommandAnswer()
        }
    }

    func settings(at place: String?) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("app settings") }
        return CommandAnswer.work {
            await app.openSettings(at: place.map { SettingsPage(place: $0) ?? .general })
            return ""
        }
    }

    func restart() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("app restart") }
        return CommandAnswer.work {
            guard await app.restart() else { throw SpotError.failed(1, "This copy of Openspot cannot start again by itself. Quit it, then open it again.") }
            return ""
        }
    }
}
