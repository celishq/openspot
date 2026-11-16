import Foundation

struct UpdateCalls {
    let app: (any RunningApp)?

    func check() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("update check") }
        return CommandAnswer.work {
            guard await app.checkUpdate() else { throw SpotError.failed(1, "This copy of Openspot does not update itself.") }
            return ""
        }
    }

    func install() -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("update install") }
        return CommandAnswer.work {
            guard await app.installUpdate() else { throw SpotError.failed(1, "No update is ready. Run `openspot update check` first.") }
            return ""
        }
    }
}
