import Foundation

struct MenuBarCalls {
    let places: AppPlaces
    let app: (any RunningApp)?

    func show(_ id: String, _ isShown: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [places, app] in
            let config = try places.config.change { $0.arrangement.set(isInMenuBar: isShown, of: id) }
            await app?.configChanged(.spots([id]), to: config)
            return ""
        }
    }
}
