import Foundation
@testable import OpenspotCore

actor FakeRunningApp: RunningApp {
    private(set) var changes = 0
    private(set) var spotChanges = 0
    private(set) var checks = 0
    private(set) var installs = 0
    private(set) var quits = 0
    private(set) var opened: [String] = []
    private var update: String?
    private var calls = 0
    private var isFirstLaunch = false
    private var slow: Bool?

    private(set) var changeList: [ConfigChange] = []

    func configChanged(_ change: ConfigChange, to config: KeptConfig) {
        changes += 1
        changeList.append(change)
    }

    func offerSlowMotion() {
        slow = false
    }

    func slowMotion(_ isOn: Bool?) -> Bool? {
        if let isOn, slow != nil { slow = isOn }
        return slow
    }

    func spotsChanged() {
        spotChanges += 1
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

    private(set) var themes: [Theme] = []

    func apply(_ theme: Theme) {
        themes.append(theme)
    }

    func open(_ id: String, at: String?) -> Bool {
        opened.append((["open", id] + (at.map { ["at", $0] } ?? [])).joined(separator: " "))
        return id != "gone"
    }

    func push(_ id: String, route: String?, title: String?, replace: Bool) -> Bool {
        opened.append((["push", id, route, replace ? "replace" : nil, title].compactMap { $0 }).joined(separator: " "))
        return id != "gone"
    }

    func pop(_ id: String, all: Bool) -> Bool {
        opened.append((["pop", id, all ? "all" : nil].compactMap { $0 }).joined(separator: " "))
        return id != "gone"
    }

    func review(_ id: String) -> Bool {
        opened.append("review \(id)")
        return id != "gone"
    }

    func act(_ act: CardAct, on id: String) -> Bool {
        opened.append("\(act.rawValue) \(id)")
        return id != "gone"
    }

    func choose(for id: String) -> Bool {
        opened.append("choose \(id)")
        return id != "gone"
    }

    func editGrid() {
        opened.append("grid")
    }

    func publish(_ id: String) -> SpotPublish {
        opened.append("publish \(id)")
        return id == "unread" ? .needsReadme : .published
    }

    func reveal(_ id: String) -> Bool {
        opened.append("reveal \(id)")
        return id != "gone"
    }

    func playground(_ file: URL?) {
        opened.append("playground \(file?.path ?? "")")
    }

    func changeSetting(_ key: String, of spot: String) -> Bool {
        opened.append("change \(spot) \(key)")
        return spot != "gone"
    }


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
