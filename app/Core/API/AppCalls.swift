import Foundation

struct AppCalls {
    let mac: any Mac
    let environment: [String: String]
    let app: (any RunningApp)?

    func status(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment, app] in
            let config = ConfigFile.standard(environment: environment).read()
            let running = await app?.status()
            return try form.text(of: AppStatus(
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                panelKey: (config.panelKey ?? .standard).text,
                fixKey: (config.fixKey ?? .fix).text,
                careful: config.isCareful,
                login: mac.login?.isOn(),
                link: mac.link?.isOn,
                update: running?.update,
                calls: running?.calls,
                firstLaunch: running?.isFirstLaunch
            ))
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

    func careful(_ isOn: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let config = try ConfigFile.standard(environment: environment).change { $0.set(isCareful: isOn) }
            await app?.configChanged(.careful, to: config)
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
