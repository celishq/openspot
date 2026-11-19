import XCTest
@testable import OpenspotCore

@MainActor
final class AppWordsTests: XCTestCase {
    private let variables = ["OPENSPOT_EDIT", "OPENSPOT_EDIT_FILE", "OPENSPOT_EDIT_FAILURE", "OPENSPOT_CONFIG", "OPENSPOT_SPOTS"]

    private func write(_ url: URL, toml: String, body: String = "echo") throws {
        try "#!/bin/sh\n\(body)\n".writeScript(to: url, toml: toml)
    }

    func testOnlyASpotOfTheAppTakesTheKeyEdits() throws {
        let folder = try temporaryFolder()
        try write(folder.appendingPathComponent("core/openspot.spot/change.sh"), toml: "title = 'Change'\nedits = 'spots'")
        try write(folder.appendingPathComponent("mine/change.spot/change.sh"), toml: "title = 'Mine'\nedits = 'spots'")

        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["openspot/change"])
        XCTAssertEqual(scan.spots.first?.edits, .spots)
        XCTAssertEqual(scan.refused.map(\.reason), ["Mine has an unknown key in its spot.toml: edits"])
    }

    func testOnlyASpotOfTheAppTakesTheKeyStarts() throws {
        let folder = try temporaryFolder()
        try write(folder.appendingPathComponent("core/openspot.spot/welcome.sh"), toml: "title = 'Welcome'\nstarts = 'first-launch'")
        try write(folder.appendingPathComponent("mine/hello.spot/hello.sh"), toml: "title = 'Mine'\nstarts = 'first-launch'")

        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["openspot/welcome"])
        XCTAssertEqual(scan.refused.map(\.reason), ["Mine has an unknown key in its spot.toml: starts"])
    }

    func testOnlyASpotOfTheAppGetsTheVariablesOfTheApp() async throws {
        let folder = try temporaryFolder()
        let body = "printf 'text=v\\ntitle=%s\\n' \"" + variables.map { "${\($0)-none}" }.joined(separator: "|") + "\""
        try write(folder.appendingPathComponent("core/openspot.spot/app.sh"), toml: "title = 'App'", body: body)
        try write(folder.appendingPathComponent("mine/mine.spot/mine.sh"), toml: "title = 'Mine'", body: body)
        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()
        let environment = TestEnvironment.values.merging(["OPENSPOT_CONFIG": folder.path, "OPENSPOT_SPOTS": folder.path]) { _, new in new }
        let runs = SpotRuns(environment: environment)
        let given = ["OPENSPOT_EDIT": "cups", "OPENSPOT_EDIT_FILE": "/cups.sh", "OPENSPOT_EDIT_FAILURE": "Down"]

        let app = try await runs.answer(of: try XCTUnwrap(scan.spots.first { $0.id == "openspot/app" }), .show, limit: 60, variables: given)
        let mine = try await runs.answer(of: try XCTUnwrap(scan.spots.first { $0.id == "mine" }), .show, limit: 60, variables: given)

        XCTAssertEqual(app, "text=v\ntitle=cups|/cups.sh|Down|\(folder.path)|\(folder.path)\n")
        XCTAssertEqual(mine, "text=v\ntitle=none|none|none|none|none\n")
    }
}
