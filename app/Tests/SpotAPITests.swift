import XCTest
@testable import OpenspotCore

/// Proves the calls of `openspot` that the spots of the app make: the list of spots, a spot turned on or off, and the
/// values that the spots keep.
final class SpotAPITests: XCTestCase {
    private struct Host: CommandHost {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    /// The running app of a test, which counts each change of the config that the API reports.
    private actor App: RunningApp {
        var changes = 0

        func configChanged() {
            changes += 1
        }
    }

    private var root: URL!
    private var plugins: URL!
    private var core: URL!
    private let app = App()

    private var file: ConfigFile {
        ConfigFile(url: root.appendingPathComponent("config.toml"))
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CORE": core.path]
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spot-api-\(UUID().uuidString.prefix(8))")
        plugins = root.appendingPathComponent("plugins")
        core = root.appendingPathComponent("core")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(host: Host(), app: app).work(for: call, input: { "" }, environment: environment))
        return await work()
    }

    private func json(_ arguments: [String]) async throws -> [[String: Any]] {
        let answer = try await answer(arguments)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]])
    }

    func testTheListHoldsEachScriptWithItsCommandsSettingsAndKeys() async throws {
        try "#!/bin/sh\n# title=Move\n# icon=macwindow\n# offers=float\n#\n# command=left\n# title=Left side\n#\n# setting=folder\n".writeScript(to: plugins.appendingPathComponent("move.sh"))
        try "#!/bin/sh\n# title=Cups\n# read=60\n".writeScript(to: plugins.appendingPathComponent("cups.sh"))
        try file.write(keys: [
            GlobalKey(spot: "move", act: .command("left"), trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+left")))),
            GlobalKey(spot: "move", act: .float, trigger: .shake)
        ])
        try file.showInMenuBar("cups", true)

        let spots = try await json(["spot", "list"])

        XCTAssertEqual(spots.map { $0["id"] as? String }, ["cups", "move"])
        let move = try XCTUnwrap(spots.last)
        XCTAssertEqual(move["name"] as? String, "Move")
        XCTAssertEqual(move["icon"] as? String, "macwindow")
        XCTAssertEqual(move["float"] as? Bool, true)
        XCTAssertEqual(move["floatKey"] as? String, "shake")
        XCTAssertEqual((move["commands"] as? [[String: Any]])?.first?["key"] as? String, "ctrl+option+left")
        XCTAssertEqual((move["settings"] as? [[String: Any]])?.map { $0["title"] as? String }, ["Folder"])
        XCTAssertEqual(spots.first?["menubar"] as? Bool, true)
        XCTAssertEqual(spots.first?["inMenuBar"] as? Bool, true)
        XCTAssertEqual(move["menubar"] as? Bool, false)
    }

    func testTheCoreListHoldsEachCoreSpotByNameAndWhetherItIsOn() async throws {
        try "#!/bin/sh\n# detail=Open app\n# icon=star\n".writeScript(to: core.appendingPathComponent("zebra.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("files.sh"))
        try "#!/bin/sh\n# read=5\n".writeScript(to: core.appendingPathComponent("cpu.sh"))
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("files.sh"))
        try file.turn("zebra", on: true)

        let spots = try await json(["spot", "list", "--core"])

        XCTAssertEqual(spots.map { $0["name"] as? String }, ["Apps", "Files", "Zebra"])
        XCTAssertEqual(spots.map { $0["on"] as? Bool }, [false, true, true])
        XCTAssertEqual(spots.map { $0["own"] as? Bool }, [false, true, false])
        XCTAssertEqual(spots.last?["detail"] as? String, "Open app")
        XCTAssertEqual(spots.last?["icon"] as? String, "star")
    }

    func testOnAndOffTurnCoreSpotsAndTellTheApp() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("zebra.sh"))

        let on = try await answer(["spot", "on", "apps", "zebra"])
        XCTAssertEqual(on, CommandAnswer())
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "zebra"])

        _ = try await answer(["spot", "off", "zebra"])
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
        let changes = await app.changes
        XCTAssertEqual(changes, 2)
    }

    func testOnRefusesAnUnknownSpotAndAFileOfTheFolderAndChangesNothing() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("files.sh"))
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("files.sh"))

        let unknown = try await answer(["spot", "on", "apps", "gone"])
        let own = try await answer(["spot", "off", "files"])

        XCTAssertEqual(unknown.errors, "`gone` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.\n")
        XCTAssertEqual(unknown.code, 1)
        XCTAssertEqual(own.errors, "`files` is a file in your plugins folder, so it is always on.\n")
        XCTAssertEqual(file.read().arrangement.enabled, [])
        let changes = await app.changes
        XCTAssertEqual(changes, 0)
    }

    func testOnWithNoSpotIsUnknown() {
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "on"], environment: [:]), .unknown("spot on"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "list", "--all"], environment: [:]), .unknown("spot list --all"))
    }

    func testTheValuesListHoldsEachValueWithItsSpot() async throws {
        try file.set(setting: "folder", of: "repos", to: "~/Code")
        try file.set(setting: "editor", of: "gone", to: "Zed")

        let values = try await json(["setting", "list"])

        XCTAssertEqual(values.map { $0["spot"] as? String }, ["repos", "gone"])
        XCTAssertEqual(values.map { $0["key"] as? String }, ["folder", "editor"])
        XCTAssertEqual(values.map { $0["value"] as? String }, ["~/Code", "Zed"])
    }
}
