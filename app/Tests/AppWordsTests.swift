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

    func testOnlyAnActionOfASpotOfTheAppIsOfferedToEveryCardWithItsKeyAndItsClose() throws {
        let folder = try temporaryFolder()
        let action = "[actions.share]\ntitle = 'Share'\nshortcut = 'cmd+shift+c'\nclose = false\noffers = ['actions mine, core']\n[actions.\"share.link\"]\ntitle = 'Copy Link'\n[actions.go]\ntitle = 'Go'"
        try write(folder.appendingPathComponent("core/openspot.spot/acts.sh"), toml: "title = 'Acts'\n\(action)")
        try write(folder.appendingPathComponent("mine/acts.spot/acts.sh"), toml: "title = 'Mine'\n\(action)")

        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()
        let acts = try XCTUnwrap(scan.spots.first)

        XCTAssertEqual(scan.spots.map(\.id), ["openspot/acts"])
        XCTAssertEqual(acts.offeredActions.map(\.action.title), ["Share", "Copy Link"])
        XCTAssertEqual(acts.offeredActions.map { $0.action.key?.label ?? "" }, ["⇧⌘C", ""])
        XCTAssertEqual(acts.offeredActions.map(\.action.after), [.stay, .close])
        XCTAssertEqual(acts.offeredActions.map(\.origins), [[.mine, .core], [.mine, .core]])
        XCTAssertEqual(acts.commands.map(\.id), ["go"])
        XCTAssertEqual(scan.refused.map(\.reason), ["Mine has an unknown key in [actions.share]: shortcut"])
    }

    func testAnOfferedActionOfASpotOfTheAppCallsItsHandlerWithTheCard() async throws {
        let folder = try temporaryFolder()
        let heard = folder.appendingPathComponent("heard")
        try write(
            folder.appendingPathComponent("core/openspot.spot/acts.sh"), toml: "title = 'Acts'\n[actions.share]\ntitle = 'Share'\noffers = ['actions']",
            body: "printf '%s %s\\n' \"$1\" \"$(sed -n 's/^input.item=//p')\" >> '\(heard.path)'"
        )
        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()
        let runs = SpotRuns(environment: TestEnvironment.values)
        runs.take(scan, menuBar: [], stamps: [:])
        defer { runs.quit() }
        let acts = try XCTUnwrap(runs.sheets["openspot/acts"])

        acts.run(try XCTUnwrap(acts.spot.offeredActions.first).action, item: SpotItem(title: "Weather", run: "weather"))

        try await wait("the call of share") { (try? String(contentsOf: heard, encoding: .utf8)) == "share weather\n" }
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

        let app = try await runs.answer(of: try XCTUnwrap(scan.spots.first { $0.id == "openspot/app" }), ScriptEntry.show.name, limit: 60, variables: given)
        let mine = try await runs.answer(of: try XCTUnwrap(scan.spots.first { $0.id == "mine" }), ScriptEntry.show.name, limit: 60, variables: given)

        XCTAssertEqual(app, "text=v\ntitle=cups|/cups.sh|Down|\(folder.path)|\(folder.path)\n")
        XCTAssertEqual(mine, "text=v\ntitle=none|none|none|none|none\n")
    }
}
