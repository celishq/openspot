import Foundation
@testable import OpenspotCore

extension AppPlaces {
    static func test(_ environment: [String: String] = [:]) -> AppPlaces {
        let name = "openspot-test-\(UUID().uuidString)"
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let own = ["OPENSPOT_CONFIG": home.appendingPathComponent("config", isDirectory: true).path].merging(environment) { _, given in given }
        return AppPlaces(environment: own, home: home, defaults: UserDefaults(suiteName: name) ?? .standard, defaultConfig: nil)
    }
}

extension CommandRequest {
    static func test(_ arguments: [String] = [], in environment: [String: String] = [:]) -> CommandRequest {
        CommandRequest(arguments: arguments, folder: environment["PWD"] ?? FileManager.default.temporaryDirectory.path)
    }
}

extension CalcRateCache {
    static var offline: CalcRateCache {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-test-\(UUID().uuidString)", isDirectory: true).appendingPathComponent("rates.json")
        return CalcRateCache(file: file, now: { Date() }) { throw URLError(.notConnectedToInternet) }
    }
}
