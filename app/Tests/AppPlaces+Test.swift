import Foundation
@testable import OpenspotCore

extension AppPlaces {
    static func test(_ environment: [String: String] = [:]) -> AppPlaces {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-test-home", isDirectory: true)
        return AppPlaces(environment: environment, home: home, defaults: .standard, defaultConfig: nil)
    }
}

extension CommandRequest {
    static func test(_ arguments: [String] = [], in environment: [String: String] = [:]) -> CommandRequest {
        CommandRequest(arguments: arguments, folder: environment["PWD"] ?? FileManager.default.temporaryDirectory.path, token: environment[CallerTokens.variable])
    }
}
