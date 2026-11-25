import XCTest
@testable import OpenspotCore

@MainActor
final class AccessListTests: XCTestCase {
    private var root: URL!
    private var spots: URL!
    private var core: URL!
    private let reads = FakeReads()
    private let accesses = FakeAccesses()
    private let clock = FakeClock()

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": core.path]
    }

    override func setUp() async throws {
        root = try temporaryFolder()
        spots = root.appendingPathComponent("spots", isDirectory: true)
        core = root.appendingPathComponent("core", isDirectory: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("lid"), toml: "title = 'Lid'\nuses = ['power']")
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("shot"), toml: "title = 'Shot'\nuses = ['screen', 'clipboard']")
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("plain"), toml: "title = 'Plain'")
    }

    private func api(runs: SpotRuns? = nil) -> CommandAPI {
        CommandAPI(mac: Mac(reads: reads, accesses: accesses), places: .test(environment), runs: runs)
    }

    private func call(_ arguments: [String], api: CommandAPI, from spot: Spot? = nil, runs: SpotRuns? = nil) async throws -> CommandAnswer {
        let request = CommandRequest(arguments: arguments, folder: root.path, caller: spot.flatMap { spot in runs.map { $0.callers.issue(for: spot) } })
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    private func records(_ text: String) -> [String: [String: String]] {
        var found: [String: [String: String]] = [:]
        for block in text.components(separatedBy: "\n\n") {
            let fields = Dictionary(block.split(separator: "\n").map { line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                return (parts[0], parts.count > 1 ? parts[1] : "")
            }) { first, _ in first }
            if let item = fields["item"] { found[item] = fields }
        }
        return found
    }

    func testAUseNeedsOnlyTheAccessesThatEachOfItsCallsNeeds() {
        let noun = CommandNoun("film", group: .mac, verbs: [
            CommandVerb("shot", "", "", rule: CallRule(use: .screen, needs: [.screen])) { _ in nil },
            CommandVerb("record", "", "", rule: CallRule(use: .screen, needs: [.screen], mayNeed: [.camera])) { _ in nil },
            CommandVerb("lid", "", "", rule: CallRule(use: .power, needs: [.helper])) { _ in nil }
        ])

        let uses = UseAccess.all(in: [noun])

        XCTAssertEqual(uses[.screen], UseAccess(needs: [.screen], optional: [.camera]))
        XCTAssertEqual(uses[.power], UseAccess(needs: [.helper], optional: []))
        XCTAssertNil(uses[.clipboard])
    }

    func testTheAppsUsesNeedTheHelperForPowerAndScreenRecordingOnlyAsAnOption() {
        XCTAssertEqual(UseAccess.all[.power]?.needs, [.helper])
        XCTAssertEqual(UseAccess.all[.screen]?.needs, [])
        XCTAssertTrue(UseAccess.all[.screen]?.optional.isSuperset(of: [.screen, .camera, .microphone, .input, .accessibility]) == true)
        XCTAssertEqual(UseAccess.all[.calendar]?.optional.isSuperset(of: [.calendars, .reminders]), true)
    }

    func testAccessListPrintsEachOfTheNineAccessesWithTheSpotsThatNeedItAndNeverAsks() async throws {
        reads.set(trust: .unasked)
        accesses.set(.helper, to: .denied)
        accesses.set(.camera, to: .unasked)

        let answer = try await call(["access", "list"], api: api())
        let found = records(answer.output)

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(Set(found.keys), ["accessibility", "automation", "screen", "calendars", "reminders", "camera", "microphone", "input", "helper"])
        XCTAssertEqual(found["helper"], ["item": "helper", "title": "Keep-awake helper", "access": "denied", "spots": "lid"])
        XCTAssertEqual(found["screen"], ["item": "screen", "title": "Screen Recording", "access": "allowed", "spots": "shot", "optional": "true"])
        XCTAssertEqual(found["accessibility"]?["access"], "unasked")
        XCTAssertEqual(found["accessibility"]?["spots"], "shot")
        XCTAssertEqual(found["camera"]?["access"], "unasked")
        XCTAssertNil(found["reminders"]?["spots"])
        XCTAssertTrue(answer.output.hasSuffix("app=com.apple.finder\npath=/Applications/Finder.app\naccess=allowed\n\napp=accessibility\naccess=unasked\n"), answer.output)
        XCTAssertFalse(reads.asks.contains { $0.hasSuffix("true") }, reads.asks.joined(separator: ", "))
    }

    func testAutomationIsDeniedWhenAnyAppItReadsIsDenied() async throws {
        reads.set(access: ["com.apple.finder": .denied])

        let answer = try await call(["access", "list"], api: api())

        XCTAssertEqual(records(answer.output)["automation"]?["access"], "denied")
    }

    func testSpotListPrintsTheStateUsesAndMissingAccessOfEachSpot() async throws {
        accesses.set(.helper, to: .denied)
        accesses.set(.screen, to: .denied)

        let answer = try await call(["spot", "list"], api: api())
        let found = records(answer.output)

        XCTAssertEqual(found["lid"]?["state"], "access")
        XCTAssertEqual(found["lid"]?["uses"], "power")
        XCTAssertEqual(found["lid"]?["needs"], "helper")
        XCTAssertEqual(found["shot"]?["state"], "ready")
        XCTAssertEqual(found["shot"]?["uses"], "clipboard,screen")
        XCTAssertNil(found["shot"]?["needs"])
        XCTAssertEqual(found["plain"]?["state"], "ready")
        XCTAssertNil(found["plain"]?["uses"])
    }

    func testTheCoreListPrintsOffForASpotThatIsNotOn() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("awake.spot/awake.sh"), toml: "uses = ['power', 'attachment']")
        accesses.set(.helper, to: .denied)

        let answer = try await call(["spot", "list", "--core"], api: api())
        let found = records(answer.output)

        XCTAssertEqual(found["awake"]?["state"], "off")
        XCTAssertEqual(found["awake"]?["uses"], "attachment,power")
        XCTAssertEqual(found["awake"]?["needs"], "helper")
    }

    func testTheLastUseOfAnAdmittedCallShowsInTheListAndSurvivesARestart() async throws {
        let stats = root.appendingPathComponent("stats", isDirectory: true)
        let runs = SpotRuns(clock: clock.value, stats: stats)
        let api = api(runs: runs)
        let shot = Spot(id: "shot", name: "Shot", url: spots.spotFile("shot"), dataName: "shot", uses: [.screen, .clipboard])

        _ = try await call(["clipboard", "read"], api: api, from: shot, runs: runs)
        let listed = try await call(["spot", "list"], api: api)
        runs.usage.flush()
        let restarted = SpotRuns(clock: clock.value, stats: stats)
        let again = try await call(["spot", "list"], api: self.api(runs: restarted))

        XCTAssertEqual(records(listed.output)["shot"]?["last.clipboard"], "1970-01-01T00:16:40Z")
        XCTAssertNil(records(listed.output)["shot"]?["last.screen"])
        XCTAssertEqual(records(again.output)["shot"]?["last.clipboard"], "1970-01-01T00:16:40Z")
    }
}
