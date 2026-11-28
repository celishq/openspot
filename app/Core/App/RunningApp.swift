import Foundation

public protocol RunningApp: Sendable {
    func configChanged(_ change: ConfigChange, to config: KeptConfig) async
    func spotsChanged() async
    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool)
    func checkUpdate() async -> Bool
    func installUpdate() async -> Bool
    func quit() async
    func apply(_ theme: Theme) async
    func open(_ id: String) async -> Bool
    func ask(_ id: String, from caller: String?, title: String?) async -> Bool
    func leave(_ id: String) async -> Bool
    func push(_ id: String, route: String?, title: String?, replace: Bool) async -> Bool
    func pop(_ id: String, all: Bool) async -> Bool
    func openSession(_ id: String) async -> Bool
    func stepSession(by steps: Int) async -> Bool
    func review(_ id: String) async -> Bool
    func act(_ act: CardAct, on id: String) async -> Bool
    func choose(for id: String) async -> Bool
    func editGrid() async
    func gridSpots() async -> [ArrangedSpot]
    func pin(_ id: String) async -> GridPin
    func putOnTop(_ id: String) async -> GridTop
    func openStore(_ id: String?, search: String?) async -> Bool
    func reveal(_ id: String) async -> Bool
    func playground(_ file: URL?) async
    func changeSetting(_ key: String, of spot: String) async -> Bool
    func allows(_ reason: String) async -> Bool
    func slowMotion(_ isOn: Bool?) async -> Bool?
    func grant(_ id: String?, needs: [MacAccess]) async -> Bool
    func grant() async -> AccessGrant?
    func endGrant() async
    func restart() async -> Bool
    func openSettings(at place: SettingsPlace?) async
    func take(_ act: PanelAct) async -> Bool
    func panelState() async -> PanelState
}

extension RunningApp {
    public func ask(_ id: String, from caller: String?, title: String?) async -> Bool {
        await open(id)
    }

    public func leave(_ id: String) async -> Bool {
        await pop(id, all: false)
    }

    public func slowMotion(_ isOn: Bool?) async -> Bool? {
        nil
    }

    public func openStore(_ id: String?, search: String?) async -> Bool {
        false
    }

    public func gridSpots() async -> [ArrangedSpot] {
        []
    }

    public func pin(_ id: String) async -> GridPin {
        .unknown
    }

    public func putOnTop(_ id: String) async -> GridTop {
        .unknown
    }
    public func grant(_ id: String?, needs: [MacAccess]) async -> Bool {
        false
    }

    public func grant() async -> AccessGrant? {
        nil
    }

    public func endGrant() async {}

    public func restart() async -> Bool {
        false
    }

    public func take(_ act: PanelAct) async -> Bool {
        false
    }

    public func panelState() async -> PanelState {
        PanelState()
    }

    public func openSettings(at place: SettingsPlace?) async {}
}
