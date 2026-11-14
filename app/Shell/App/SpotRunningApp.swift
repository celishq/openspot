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
        await model.open(id)
    }

    func push(_ id: String, page: String?, title: String?, replace: Bool) async -> Bool {
        await model.push(FlowSheet(spot: id, page: page, title: title), replace: replace)
    }

    func pop(_ id: String, all: Bool) async -> Bool {
        await all ? model.pop(in: id, all: true) : model.pop(in: id)
    }

    func choose(for id: String) async -> Bool {
        await model.chooseFiles(for: id)
    }

    func act(_ act: CardAct, on id: String) async -> Bool {
        await model.act(act, on: id)
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
