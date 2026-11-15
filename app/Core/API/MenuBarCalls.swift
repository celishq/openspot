import Foundation

struct MenuBarCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    func show(_ id: String, _ isShown: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let config = try ConfigFile.standard(environment: environment).change { $0.arrangement.set(isInMenuBar: isShown, of: id) }
            await app?.configChanged(.spots([id]), to: config)
            return ""
        }
    }
}
