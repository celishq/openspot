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
    func ask(_ id: String, from caller: String?, title: String?) async -> Bool { await model.present(FlowSheet(spot: id, title: title), from: caller) }
    func leave(_ id: String) async -> Bool { await model.leave(id) }
    func push(_ id: String, route: String?, title: String?, replace: Bool) async -> Bool { false }
    func pop(_ id: String, all: Bool) async -> Bool { await all ? model.pop(in: id, all: true) : model.pop(in: id) }
    func review(_ id: String) async -> Bool {
        if await model.review(spot: id) { return true }
        if await model.isOwnSpot(id) { return false }
        return await openStore(id, search: nil)
    }
    func choose(for id: String) async -> Bool { false }
    func editGrid() async {}
    func gridSpots() async -> [ArrangedSpot] { await model.gridSpots() }
    func pin(_ id: String) async -> GridPin { await model.pin(id) }
    func push(_ id: String) async -> GridPin { await model.push(id) }
    func reveal(_ id: String) async -> Bool { false }
    func playground(_ file: URL?) async {}
    func changeSetting(_ key: String, of spot: String) async -> Bool { false }
    func allows(_ reason: String) async -> Bool { false }
    func grant(_ id: String?, needs: [MacAccess]) async -> Bool { await model.grant(id, needs: needs) }
    func grant() async -> AccessGrant? { await model.grant }
    func endGrant() async { await model.endGrant() }
    func openSettings(at place: SettingsPlace?) async { await model.openSettings(at: place) }
}
