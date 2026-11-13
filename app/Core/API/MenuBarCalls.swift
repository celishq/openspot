import Foundation

/// The call of `openspot menubar`: a spot in the menu bar, or out of it.
struct MenuBarCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    func show(_ id: String, _ isShown: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            try ConfigFile.standard(environment: environment).showInMenuBar(id, isShown)
            await app?.configChanged(.spots([id]))
            return ""
        }
    }
}
