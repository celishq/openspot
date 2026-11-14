import Foundation

public protocol RunningApp: Sendable {
    func configChanged(_ change: ConfigChange) async
    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool)
    func checkUpdate() async -> Bool
    func installUpdate() async -> Bool
    func quit() async
    func open(_ id: String) async -> Bool
    func push(_ id: String, page: String?, title: String?, replace: Bool) async -> Bool
    func pop(_ id: String, all: Bool) async -> Bool
    func review(_ id: String) async -> Bool
    func act(_ act: CardAct, on id: String) async -> Bool
    func choose(for id: String) async -> Bool
    func editGrid() async
    func publish(_ id: String) async -> SpotPublish
    func reveal(_ id: String) async -> Bool
    func sandbox(_ file: URL?, isCareful: Bool) async
    func changeSetting(_ key: String, of spot: String) async -> Bool
    func allows(_ reason: String) async -> Bool
}
