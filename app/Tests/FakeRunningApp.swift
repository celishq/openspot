import Foundation
@testable import OpenspotCore

/// The running app of a test. It counts each change of the config that the API reports, records each act that the API
/// asks for, and answers the status that the test sets. A spot called `gone` does not exist.
actor FakeRunningApp: RunningApp {
    private(set) var changes = 0
    private(set) var checks = 0
    private(set) var installs = 0
    private(set) var quits = 0
    private(set) var opened: [String] = []
    private var update: String?
    private var calls = 0
    private var isFirstLaunch = false

    /// Each change of the config that the API reported, in order.
    private(set) var changeList: [ConfigChange] = []

    func configChanged(_ change: ConfigChange) {
        changes += 1
        changeList.append(change)
    }

    func status() -> (update: String?, calls: Int, isFirstLaunch: Bool) {
        (update, calls, isFirstLaunch)
    }

    func checkUpdate() -> Bool {
        checks += 1
        return true
    }

    func installUpdate() -> Bool {
        installs += 1
        return update != nil
    }

    func quit() {
        quits += 1
    }

    func open(_ id: String) -> Bool {
        opened.append("open \(id)")
        return id != "gone"
    }

    func review(_ id: String) -> Bool {
        opened.append("review \(id)")
        return id != "gone"
    }

    func openStore() {
        opened.append("store")
    }

    func reveal(_ id: String) -> Bool {
        opened.append("reveal \(id)")
        return id != "gone"
    }

    func sandbox(_ file: URL?, isCareful: Bool) {
        opened.append("sandbox \(file?.path ?? "") careful=\(isCareful)")
    }

    func changeSetting(_ key: String, of spot: String) -> Bool {
        opened.append("change \(spot) \(key)")
        return spot != "gone"
    }


    /// Each reason that Touch ID was asked for, and whether the person passes it.
    private(set) var asked: [String] = []
    private var allowsActs = true

    func allows(_ reason: String) -> Bool {
        asked.append(reason)
        return allowsActs
    }

    func set(allows: Bool) {
        allowsActs = allows
    }

    func set(update: String?, calls: Int, isFirstLaunch: Bool = false) {
        self.update = update
        self.calls = calls
        self.isFirstLaunch = isFirstLaunch
    }
}
