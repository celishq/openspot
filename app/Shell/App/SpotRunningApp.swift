import AppKit
import OpenspotCore

/// The app as the API reaches it while it runs.
struct SpotRunningApp: RunningApp {
    let model: SpotsModel
    let update: AppUpdate?

    func configChanged(_ change: ConfigChange) async {
        await model.configChanged(change)
    }

    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) {
        await MainActor.run { (update?.ready, model.workCount, model.isFirstLaunch) }
    }

    func checkUpdate() async -> Bool {
        await MainActor.run {
            guard let update else { return false }
            update.check()
            return true
        }
    }

    func installUpdate() async -> Bool {
        await MainActor.run { update?.restart() ?? false }
    }

    func quit() async {
        await MainActor.run { NSApp.terminate(nil) }
    }

    func open(_ id: String) async -> Bool {
        await model.openSheet(id)
    }

    func float(_ id: String) async -> Bool {
        await model.showFloat(id)
    }

    func review(_ id: String) async -> Bool {
        await model.reviewCore(id)
    }

    func openStore() async {
        await model.openStore()
    }

    func reveal(_ id: String) async -> Bool {
        await model.reveal(id)
    }

    func sandbox(_ file: URL?, isCareful: Bool) async {
        await SpotSandbox.show(path: file?.path, isCareful: isCareful)
    }

    func changeSetting(_ key: String, of spot: String) async -> Bool {
        await model.changeSetting(key, of: spot)
    }

    func allows(_ reason: String) async -> Bool {
        await model.allows(reason)
    }

}
