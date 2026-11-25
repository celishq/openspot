import XCTest
@testable import OpenspotCore

@MainActor
final class AccessGrantTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!
    private var clock: FakeClock!
    private var accesses: FakeAccesses!

    private let settings = "openspot/settings"

    override func setUp() async throws {
        folder = try temporaryFolder()
        suite = "openspot-grant-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let app = core.appendingPathComponent("openspot.spot", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try "[scripts.settings]\ntitle = 'Settings'\nwindow = 'settings'\nedits = 'settings'\n"
            .write(to: app.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\nat=$(sed -n 's/^input\\.at=//p')\necho \"$1 $at\" >> '\(log.path)'\nprintf 'item=a\\ntitle=Apple\\n'\n"
            .writeScript(to: app.appendingPathComponent("settings.sh"))
        try "#!/bin/sh\necho ran >> '\(folder.appendingPathComponent("runs").path)'\nopenspot calendar events\nopenspot screen shot\n".writeScript(to: spots.spotFile("standup"), toml: "title = 'Standup'\nuses = ['calendar', 'screen']")
        try "#!/bin/sh\nopenspot calendar events\n".writeScript(to: spots.spotFile("agenda"), toml: "title = 'Agenda'\nuses = ['calendar']")
        try "#!/bin/sh\necho hi\n".writeScript(to: spots.spotFile("plain"), toml: "title = 'Plain'")
        accesses = FakeAccesses([.calendars: .denied, .screen: .denied])
        try await start()
    }

    override func tearDown() async throws {
        model.endGrant()
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private func start() async throws {
        host = FakeHost()
        clock = FakeClock()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: 0.2))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(accesses: accesses), places: files, app: ModelApp(model: model), runs: model.runs)
        await model.reload()
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private var core: URL {
        folder.appendingPathComponent("core", isDirectory: true)
    }

    private var log: URL {
        folder.appendingPathComponent("shows")
    }

    private var shows: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let request = CommandRequest(arguments: arguments, folder: folder.path)
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    private func turn(_ access: MacAccess) async throws {
        try await wait("the watch sleeps") { self.clock.sleepCount == 1 }
        accesses.set(access, to: .allowed)
        clock.advance(by: 1)
    }

    func testAllowWithNoUseOpensSettingsAtTheSpotAndAsksForTheFirstAccess() async throws {
        let answer = try await call(["spot", "allow", "standup"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Settings walks you through Calendars and Screen Recording.\n")
        XCTAssertEqual(model.grant?.steps, [.calendars, .screen])
        XCTAssertEqual(model.grant?.step, .calendars)
        try await wait("the window at the spot") { self.host.windows == [self.settings] && self.shows.contains("show spot/standup") }
        try await wait("the ask for calendars") { self.accesses.asks == [.calendars] }
    }

    func testAllowSaysSoWhenTheSpotNeedsNoAccess() async throws {
        let answer = try await call(["spot", "allow", "plain"])

        XCTAssertEqual(answer.output, "Plain has each macOS access it needs.\n")
        XCTAssertNil(model.grant)
        XCTAssertEqual(host.windows, [])
    }

    func testAStepMovesOnWhenItsAccessTurnsOnAndTheWindowTakesItsFocusBack() async throws {
        _ = try await call(["spot", "allow", "standup"])

        try await turn(.calendars)

        try await wait("the next step") { self.model.grant?.step == .screen }
        XCTAssertEqual(host.focusedWindows, [settings])
        try await wait("the ask for the screen") { self.accesses.asks == [.calendars, .screen] }
        XCTAssertEqual(clock.tolerances.first ?? nil, .milliseconds(250))
    }

    func testAccessGrantPrintsTheStepItWaitsOnAndWhereItsSwitchIs() async throws {
        _ = try await call(["spot", "allow", "standup"])
        try await turn(.calendars)
        try await wait("the next step") { self.model.grant?.step == .screen }

        let answer = try await call(["access", "grant"])

        XCTAssertEqual(answer.output, "item=grant\nspot=standup\nsteps=calendars,screen\nstep=screen\ndone=calendars\nplace=Privacy & Security › Screen & System Audio Recording\nrestart=true\n")
    }

    func testTheLastAccessEndsTheGrantAndTheWatch() async throws {
        accesses.set(.screen, to: .allowed)
        _ = try await call(["spot", "allow", "standup"])
        XCTAssertEqual(model.grant?.steps, [.calendars])

        try await turn(.calendars)

        try await wait("the end of the grant") { self.model.grant == nil }
        XCTAssertEqual(host.focusedWindows, [settings])
        try await wait("the marks go") { self.model.waiting.isEmpty }
        let answer = try await call(["access", "grant"])
        XCTAssertEqual(answer.output, "")
        let reads = accesses.reads.count
        clock.advance(by: 10)
        XCTAssertEqual(clock.sleepCount, 0)
        XCTAssertEqual(accesses.reads.count, reads)
    }

    func testEndStopsTheWatch() async throws {
        _ = try await call(["spot", "allow", "standup"])
        try await wait("the watch sleeps") { self.clock.sleepCount == 1 }

        let answer = try await call(["access", "grant", "--end"])

        XCTAssertEqual(answer.output, "")
        XCTAssertNil(model.grant)
        try await wait("the watch ends") { self.clock.sleepCount == 0 }
        XCTAssertNil(defaults.stringArray(forKey: SpotsModel.grantKey))
    }

    func testAStepThatNeedsARestartIsKeptAndSettingsOpensAgainAtItAfterTheStart() async throws {
        _ = try await call(["spot", "allow", "standup"])
        XCTAssertNil(defaults.stringArray(forKey: SpotsModel.grantKey))
        try await turn(.calendars)
        try await wait("the screen step") { self.model.grant?.step == .screen }
        XCTAssertEqual(defaults.stringArray(forKey: SpotsModel.grantKey), ["standup", "calendars", "screen"])

        model.quit()
        try await start()
        await model.resumeGrant()

        XCTAssertEqual(model.grant?.step, .screen)
        try await wait("the window at the spot") { self.host.windows == [self.settings] }
        try await wait("the watch sleeps") { self.clock.sleepCount == 1 }
        accesses.set(.screen, to: .allowed)
        clock.advance(by: 1)
        try await wait("the end of the grant") { self.model.grant == nil }
        XCTAssertNil(defaults.stringArray(forKey: SpotsModel.grantKey))
    }

    func testACardWhoseSpotNeedsAccessIsMarkedAndItsPressOpensSettingsAtItInsteadOfARun() async throws {
        try await wait("the marks") { self.model.waiting == ["standup", "agenda"] }

        model.press("standup")

        try await wait("the window at the spot") { self.host.windows == [self.settings] && self.shows.contains("show spot/standup") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("runs").path))
    }

    func testThePressOfAMarkedCardAndItsSettingsActionOpenTheSameWindowAtTheSpot() async throws {
        try await wait("the marks") { self.model.waiting == ["standup", "agenda"] }

        model.press("standup")
        try await wait("the press at the spot") { self.shows.filter { $0 == "show spot/standup" }.count == 1 }
        XCTAssertTrue(model.act(.settings, on: "standup"))
        try await wait("the action at the spot") { self.shows.filter { $0 == "show spot/standup" }.count == 2 }

        XCTAssertEqual(host.windows, [settings, settings])
    }

    func testAReadySpotIsNotMarkedAndItsPressRunsIt() async throws {
        accesses.set(.calendars, to: .allowed)
        accesses.set(.screen, to: .allowed)
        model.readWaiting()
        try await wait("no marks") { self.model.waiting.isEmpty }

        model.press("standup")

        try await wait("the run") { FileManager.default.fileExists(atPath: self.folder.appendingPathComponent("runs").path) }
        XCTAssertEqual(host.windows, [])
    }
}
