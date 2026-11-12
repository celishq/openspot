import Foundation

/// The calls of `openspot app`: the state of the app, its login and terminal settings, and its quit.
struct AppCalls {
    let mac: any Mac
    let environment: [String: String]
    let app: (any RunningApp)?

    func status(frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment, app] in
            let config = ConfigFile.standard(environment: environment).read()
            let running = await app?.status()
            return try AppStatus(
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                panelKey: (config.panelKey ?? .standard).text,
                fixKey: (config.fixKey ?? .fix).text,
                careful: config.isCareful,
                login: mac.login?.isOn(),
                link: mac.link?.isOn,
                update: running?.update,
                calls: running?.calls,
                firstLaunch: running?.isFirstLaunch
            ).text(frame: frame)
        }
    }

    func login(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let login = mac.login else { throw SpotError.failed(1, "This copy of Openspot cannot open at login. Move it to Applications, then try again.") }
            try login.set(isOn)
            return ""
        }
    }

    func link(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let link = mac.link else { throw SpotError.failed(1, "This copy of Openspot cannot put openspot in Terminal.") }
            try link.set(isOn)
            return ""
        }
    }

    /// Turns Careful mode on or off, and tells the running app (Z8).
    func careful(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            try ConfigFile.standard(environment: environment).set("careful", to: isOn)
            await app?.configChanged(.careful)
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
}
