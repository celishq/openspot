import XCTest
@testable import OpenspotCore

/// Proves the calls of `openspot` that the spots of the app make: the list of spots, a spot turned on or off, and the
/// values that the spots keep.
final class SpotAPITests: XCTestCase {
    private final class Login: @unchecked Sendable {
        var isOn = false
    }

    private final class Host: Mac {
        let login: LoginItem?

        init(login: LoginItem? = nil) {
            self.login = login
        }

        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    private var root: URL!
    private var spots: URL!
    private var core: URL!
    private let app = FakeRunningApp()

    private var file: ConfigFile {
        ConfigFile(url: root.appendingPathComponent("config.toml"))
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": core.path]
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spot-api-\(UUID().uuidString.prefix(8))")
        spots = root.appendingPathComponent("spots")
        core = root.appendingPathComponent("core")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func answer(_ arguments: [String], host: Host = Host(), app: (any RunningApp)? = nil, reason: String? = nil) async throws -> CommandAnswer {
        let environment = environment.merging(reason.map { ["OPENSPOT_REASON": $0] } ?? [:]) { _, new in new }
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: host, app: app ?? self.app).work(for: call, input: { "" }, environment: environment))
        return await work()
    }

    private func appWork(_ arguments: [String]) throws -> CommandAPI.Work? {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        return CommandAPI(mac: Host()).work(for: call, input: { "" }, environment: environment)
    }

    private func json(_ arguments: [String]) async throws -> [[String: Any]] {
        let answer = try await answer(arguments)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]])
    }

    func testTheListHoldsEachScriptWithItsCommandsSettingsAndKeys() async throws {
        try "#!/bin/sh\n# title=Move\n# icon=macwindow\n# on=sheet.open\n# offers=card\n# offers=float\n#\n# button=left\n# title=Left side\n#\n# field=folder\n".writeScript(to: spots.spotFile("move"))
        try "#!/bin/sh\n# title=Cups\n# on=clock.60\n# offers=card\n# offers=menubar\n".writeScript(to: spots.spotFile("cups"))
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
        XCTAssertEqual((move["buttons"] as? [[String: Any]])?.first?["key"] as? String, "ctrl+option+left")
        XCTAssertEqual((move["fields"] as? [[String: Any]])?.map { $0["title"] as? String }, ["Folder"])
        XCTAssertEqual(spots.first?["menubar"] as? Bool, true)
        XCTAssertEqual(spots.first?["inMenuBar"] as? Bool, true)
        XCTAssertEqual(move["menubar"] as? Bool, false)
    }

    func testTheCoreListHoldsEachCoreSpotByNameAndWhetherItIsOn() async throws {
        try "#!/bin/sh\n# detail=Open app\n# icon=star\n".writeScript(to: core.appendingPathComponent("zebra.spot/zebra.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("files.spot/files.sh"))
        try "#!/bin/sh\n# on=clock.5\n".writeScript(to: core.appendingPathComponent("cpu.spot/cpu.sh"))
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("files"))
        try file.turn("zebra", on: true)

        let spots = try await json(["spot", "list", "--core"])

        XCTAssertEqual(spots.map { $0["name"] as? String }, ["Apps", "Files", "Zebra"])
        XCTAssertEqual(spots.map { $0["on"] as? Bool }, [false, true, true])
        XCTAssertEqual(spots.map { $0["own"] as? Bool }, [false, true, false])
        XCTAssertEqual(spots.last?["detail"] as? String, "Open app")
        XCTAssertEqual(spots.last?["icon"] as? String, "star")
    }

    func testOnAndOffTurnCoreSpotsAndTellTheApp() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("zebra.spot/zebra.sh"))

        let on = try await answer(["setting", "set", "--spot", "apps", "enabled", "true"])
        XCTAssertEqual(on, CommandAnswer())
        _ = try await answer(["setting", "set", "--spot", "zebra", "enabled", "true"])
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "zebra"])

        _ = try await answer(["setting", "set", "--spot", "zebra", "enabled", "false"])
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
        let changes = await app.changes
        XCTAssertEqual(changes, 3)
    }

    func testOnRefusesAnUnknownSpotAndAFileOfTheFolderAndChangesNothing() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("files.spot/files.sh"))
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("files"))

        let unknown = try await answer(["setting", "set", "--spot", "gone", "enabled", "true"])
        let own = try await answer(["setting", "set", "--spot", "files", "enabled", "false"])

        XCTAssertEqual(unknown.errors, "`gone` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.\n")
        XCTAssertEqual(unknown.code, 1)
        XCTAssertEqual(own.errors, "`files` is a file in your spots folder, so it is always on.\n")
        XCTAssertEqual(file.read().arrangement.enabled, [])
        let changes = await app.changes
        XCTAssertEqual(changes, 0)
    }

    func testOnWithNoSpotIsUnknown() {
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "--spot", "a", "enabled"], environment: [:]), .refused("`enabled` takes `true` or `false`, such as `openspot setting set --spot a enabled true`."))
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

    func testKeySetGivesACommandAKeyAndTakesItAway() async throws {
        _ = try await answer(["setting", "set", "--spot", "move", "key.left", "ctrl+option+left"])
        _ = try await answer(["setting", "set", "--spot", "move", "key.left", "ctrl+option+up"])
        _ = try await answer(["setting", "set", "--spot", "move", "key.right", "ctrl+option+right"])

        XCTAssertEqual(file.read().keys.map(\.act), [.command("left"), .command("right")])
        XCTAssertEqual(file.read().keys.map(\.trigger.text), ["ctrl+option+up", "ctrl+option+right"])

        _ = try await answer(["setting", "set", "--spot", "move", "key.left"])

        XCTAssertEqual(file.read().keys.map(\.act), [.command("right")])
        let changes = await app.changes
        XCTAssertEqual(changes, 4)
    }

    func testAShakeTakesTheShakeFromTheKeyThatHadIt() async throws {
        _ = try await answer(["setting", "set", "--spot", "shelf", "float", "shake"])
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "shelf", act: .float, trigger: .shake)])

        _ = try await answer(["setting", "set", "--spot", "notes", "float", "shake"])

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
    }

    func testTheKeysOfTheAppTakeAKeyAndRefuseAShake() async throws {
        let panel = try await answer(["setting", "set", "--spot", "openspot", "panel-key", "option+space"])
        let fix = try await answer(["setting", "set", "--spot", "openspot", "fix-key", "ctrl+option+f"])
        let shake = try await answer(["setting", "set", "--spot", "openspot", "panel-key", "shake"])
        let bad = try await answer(["setting", "set", "--spot", "move", "key.left", "k"])

        XCTAssertEqual(panel, CommandAnswer())
        XCTAssertEqual(fix, CommandAnswer())
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertEqual(shake.code, 1)
        XCTAssertEqual(shake.errors, "Openspot cannot use `shake`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.\n")
        XCTAssertEqual(bad.code, 1)
        XCTAssertEqual(file.read().keys, [])
    }

    func testAKeyItCannotUseLeavesTheFile() async throws {
        _ = try await answer(["setting", "set", "--spot", "openspot", "panel-key", "k"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
    }

    func testKeySetReadsItsWords() {
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "--spot", "a", "float"], environment: [:]), .keySet(spot: "a", act: .float, key: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "--spot", "a", "key.go", "cmd+k"], environment: [:]), .keySet(spot: "a", act: .command("go"), key: "cmd+k"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "--spot", "openspot", "panel-key"], environment: [:]), .refused("`panel-key` needs a key, such as `openspot setting set --spot openspot panel-key ctrl+space`."))
    }

    func testMenuBarPutsASpotInAndTakesItOut() async throws {
        _ = try await answer(["setting", "set", "--spot", "cups", "menubar", "true"])
        XCTAssertEqual(file.read().arrangement.menuBar, ["cups"])

        _ = try await answer(["setting", "set", "--spot", "cups", "menubar", "false"])

        XCTAssertEqual(file.read().arrangement.menuBar, [])
        let changes = await app.changes
        XCTAssertEqual(changes, 2)
    }

    func testTheStatusOfTheAppNamesItsKeysAndWhatOnlyTheRunningAppKnows() async throws {
        try file.set("panel_key", to: "option+space")
        await app.set(update: "0.3.0", calls: 2, isFirstLaunch: true)

        let running = try await answer(["app", "status"])
        let alone = try await XCTUnwrap(appWork(["app", "status"]))()

        let status = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(running.output.utf8)) as? [String: Any])
        XCTAssertEqual(status["panelKey"] as? String, "option+space")
        XCTAssertEqual(status["fixKey"] as? String, "cmd+option+o")
        XCTAssertEqual(status["update"] as? String, "0.3.0")
        XCTAssertEqual(status["calls"] as? Int, 2)
        XCTAssertEqual(status["firstLaunch"] as? Bool, true)
        XCTAssertNil(status["login"])
        let quiet = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(alone.output.utf8)) as? [String: Any])
        XCTAssertNil(quiet["update"])
        XCTAssertNil(quiet["calls"])
        XCTAssertNotNil(quiet["version"])
    }

    func testLoginTurnsTheLoginItemOnAndOff() async throws {
        let state = Login()
        let host = Host(login: LoginItem(isOn: { state.isOn }, set: { state.isOn = $0 }))

        _ = try await answer(["setting", "set", "--spot", "openspot", "login", "true"], host: host)
        XCTAssertTrue(state.isOn)
        let status = try await answer(["app", "status"], host: host)
        XCTAssertTrue(status.output.contains("\"login\":true"))

        _ = try await answer(["setting", "set", "--spot", "openspot", "login", "false"], host: host)
        XCTAssertFalse(state.isOn)
        let none = try await answer(["setting", "set", "--spot", "openspot", "login", "true"])
        XCTAssertEqual(none.errors, "This copy of Openspot cannot open at login. Move it to Applications, then try again.\n")
    }

    func testTheRunningAppChecksInstallsAndQuits() async throws {
        let none = try await answer(["update", "install"])
        XCTAssertEqual(none.errors, "No update is ready. Run `openspot update check` first.\n")
        await app.set(update: "0.3.0", calls: 0)

        _ = try await answer(["update", "check"])
        let install = try await answer(["update", "install"])
        _ = try await answer(["app", "quit"])

        XCTAssertEqual(install, CommandAnswer())
        let checks = await app.checks
        let installs = await app.installs
        let quits = await app.quits
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(installs, 2)
        XCTAssertEqual(quits, 1)
    }

    func testWithNoRunningAppTheActsOfTheAppFail() async throws {
        for arguments in [["app", "quit"], ["update", "check"], ["update", "install"]] {
            let answer = try await XCTUnwrap(appWork(arguments))()
            let call = "openspot " + arguments.joined(separator: " ")
            XCTAssertEqual(answer.errors, "`\(call)` needs the Openspot app, and no app answers. Open Openspot, or quit it and open it again if it is open, then run `\(call)` again.\n", call)
            XCTAssertEqual(answer.code, 1)
        }
    }

    func testAReadCannotQuitOrRestartTheApp() {
        let read = ["OPENSPOT_REASON": "panel"]

        XCTAssertEqual(CommandLineCall(arguments: ["app", "quit"], environment: read), .refused("`openspot app quit` ends Openspot, so it cannot run in a read. Run it from a pick or an action."))
        XCTAssertEqual(CommandLineCall(arguments: ["update", "install"], environment: read), .refused("`openspot update install` restarts Openspot, so it cannot run in a read. Run it from a pick or an action."))
        XCTAssertEqual(CommandLineCall(arguments: ["app", "status"], environment: read), .appStatus(frame: false))
    }

    func testTheRunningAppOpensASheetAReviewAndAChangeOfASetting() async throws {
        _ = try await answer(["spot", "open", "notes"])
        _ = try await answer(["spot", "review", "apps"])
        let change = try await answer(["setting", "change", "--spot", "repos", "folder"])
        let gone = try await answer(["spot", "open", "gone"])
        let goneReview = try await answer(["spot", "review", "gone"])

        XCTAssertEqual(change, CommandAnswer())
        let opened = await app.opened
        XCTAssertEqual(opened, ["open notes", "review apps", "change repos folder", "open gone", "review gone"])
        XCTAssertEqual(gone.errors, "Openspot has no spot `gone`. Run `openspot spot list` to see each one.\n")
        XCTAssertEqual(goneReview.code, 1)
        for arguments in [["spot", "open", "notes"], ["spot", "review", "apps"], ["setting", "change", "--spot", "a", "b"]] {
            let answer = try await XCTUnwrap(appWork(arguments))()
            XCTAssertEqual(answer.code, 1, arguments.joined(separator: " "))
        }
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "open", "notes"], environment: ["OPENSPOT_REASON": "panel"]), .refused("`openspot spot open` opens the panel, so it cannot run in a read. Run it from a pick or an action."))
    }

    func testTheRunningAppAsksForFilesForASpotThatTakesThem() async throws {
        let chose = try await answer(["spot", "choose", "shelf"])
        let gone = try await answer(["spot", "choose", "gone"])

        let opened = await app.opened
        XCTAssertEqual(chose, CommandAnswer())
        XCTAssertEqual(opened, ["choose shelf", "choose gone"])
        XCTAssertEqual(gone.errors, "Openspot has no spot `gone` that takes files. Add drop= to its header.\n")
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "choose", "shelf"], environment: ["OPENSPOT_REASON": "panel"]), .refused("`openspot spot choose` opens a window, so it cannot run in a read. Run it from a pick or an action."))
    }

    func testThePromptAsksForASpotInTheSpotsFolder() async throws {
        let answer = try await answer(["prompt", "new", "Show", "the weather"])

        XCTAssertTrue(answer.output.hasPrefix("Build an Openspot spot that does this: Show the weather\n"))
        XCTAssertTrue(answer.output.contains(spots.path))
        XCTAssertEqual(CommandLineCall(arguments: ["prompt", "new"], environment: [:]), .unknown("prompt new"))
    }
}
