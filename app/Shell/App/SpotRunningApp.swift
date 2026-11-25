import AppKit
import OpenspotCore

struct SpotRunningApp: RunningApp {
    private static let answerPause: TimeInterval = 0.2

    let model: SpotsModel
    let update: AppUpdate?

    func configChanged(_ change: ConfigChange, to config: KeptConfig) async {
        await model.configChanged(change, to: config)
    }

    func spotsChanged() async {
        await model.spotsChanged()
    }

    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) {
        await MainActor.run { (update?.readyVersion, model.actCount, model.isFirstLaunch) }
    }

    func slowMotion(_ isOn: Bool?) async -> Bool? {
        await MainActor.run { model.slowMotion(isOn) }
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
        await MainActor.run {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.answerPause) { NSApp.terminate(nil) }
        }
    }

    func apply(_ theme: Theme) async {
        await MainActor.run {
            model.take(theme)
        }
    }

    func open(_ id: String, at: String?) async -> Bool {
        await model.open(id, at: at)
    }

    func ask(_ id: String, from caller: String?, title: String?) async -> Bool {
        await model.present(FlowSheet(spot: id, title: title), from: caller)
    }

    func leave(_ id: String) async -> Bool {
        await model.leave(id)
    }

    func push(_ id: String, route: String?, title: String?, replace: Bool) async -> Bool {
        await model.present(FlowSheet(spot: id, route: route, title: title), replace: replace)
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

    func editGrid() async {
        await model.editGrid()
    }

    func publish(_ id: String) async -> SpotPublish {
        await model.publish(id)
    }

    func reveal(_ id: String) async -> Bool {
        await model.reveal(id)
    }

    func playground(_ file: URL?, isCareful: Bool) async {
        await SpotPlayground.show(path: file?.path, isCareful: isCareful)
    }

    func changeSetting(_ key: String, of spot: String) async -> Bool {
        await model.changeSetting(key, of: spot)
    }

    func allows(_ reason: String) async -> Bool {
        await model.allows(reason)
    }

}
