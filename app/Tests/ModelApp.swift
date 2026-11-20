import Foundation
@testable import OpenspotCore

struct ModelApp: RunningApp {
    let model: SpotsModel

    func act(_ act: CardAct, on id: String) async -> Bool { await model.act(act, on: id) }
    func configChanged(_ change: ConfigChange, to config: KeptConfig) async { await model.configChanged(change, to: config) }
    func spotsChanged() async { await model.spotsChanged() }
    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) { (nil, 0, false) }
    func checkUpdate() async -> Bool { false }
    func slowMotion(_ isOn: Bool?) async -> Bool? { await model.slowMotion(isOn) }
    func installUpdate() async -> Bool { false }
    func quit() async {}
    func apply(_ theme: Theme) async {}
    func open(_ id: String) async -> Bool { await model.open(id) }
    func ask(_ id: String) async -> Bool { await model.openAsked(id) }
    func push(_ id: String, route: String?, title: String?, replace: Bool) async -> Bool { false }
    func pop(_ id: String, all: Bool) async -> Bool { await all ? model.pop(in: id, all: true) : model.pop(in: id) }
    func review(_ id: String) async -> Bool { false }
    func choose(for id: String) async -> Bool { false }
    func editGrid() async {}
    func publish(_ id: String) async -> SpotPublish { .notOwn }
    func reveal(_ id: String) async -> Bool { false }
    func playground(_ file: URL?, isCareful: Bool) async {}
    func changeSetting(_ key: String, of spot: String) async -> Bool { false }
    func allows(_ reason: String) async -> Bool { false }
}
