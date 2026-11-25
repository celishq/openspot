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
        try "#!/bin/sh\nopenspot power lid-closed\n".writeScript(to: spots.spotFile("lid"), toml: "title = 'Lid'\nuses = ['power']")
        try "#!/bin/sh\nopenspot screen record start display mic \"$1\"\nopenspot clipboard copy\n".writeScript(to: spots.spotFile("shot"), toml: "title = 'Shot'\nuses = ['screen', 'clipboard']")
        try "#!/bin/sh\nopenspot color pick\n".writeScript(to: spots.spotFile("pick"), toml: "title = 'Pick'\nuses = ['screen']")
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

    func testASpotNeedsTheAccessOfEachCallInItsFilesAndMayNeedTheRest() throws {
        let script = spots.spotFile("film")
        try "#!/bin/sh\nopenspot screen shot\n".writeScript(to: script, toml: "views = ['film.js']")
        try "openspot.call([\"calendar\", \"events\"])\nopenspot.call([\"screen\", \"record\", \"start\"])\n".write(to: script.deletingLastPathComponent().appendingPathComponent("film.js"), atomically: true, encoding: .utf8)
        let spot = Spot(id: "film", name: "Film", url: script, dataName: "film", views: ["film": script.deletingLastPathComponent().appendingPathComponent("film.js").path])

        let standing = SpotStanding(spot, statuses: [:], last: ["window move": Date()], refused: [:])

        XCTAssertEqual(standing.needs, [.screen, .calendars, .accessibility])
        XCTAssertEqual(standing.maybe, [.camera, .microphone, .input])
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
        XCTAssertEqual(found["screen"], ["item": "screen", "title": "Screen Recording", "access": "allowed", "spots": "shot"])
        XCTAssertEqual(found["camera"], ["item": "camera", "title": "Camera", "access": "unasked", "maybe": "shot"])
        XCTAssertEqual(found["accessibility"], ["item": "accessibility", "title": "Accessibility", "access": "unasked"])
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
        XCTAssertEqual(found["shot"]?["state"], "access")
        XCTAssertEqual(found["shot"]?["uses"], "clipboard,screen")
        XCTAssertEqual(found["shot"]?["needs"], "screen")
        XCTAssertEqual(found["pick"]?["state"], "ready")
        XCTAssertNil(found["pick"]?["needs"])
        XCTAssertEqual(found["plain"]?["state"], "ready")
        XCTAssertNil(found["plain"]?["uses"])
    }

    func testSpotListPrintsUnderEachUseTheAccessItsCallsNeedAllowedOrNot() async throws {
        accesses.set(.screen, to: .allowed)

        let answer = try await call(["spot", "list"], api: api())
        let found = records(answer.output)

        XCTAssertEqual(found["shot"]?["access.screen"], "screen")
        XCTAssertEqual(found["shot"]?["maybe.screen"], "camera,microphone,input")
        XCTAssertNil(found["shot"]?["access.clipboard"])
        XCTAssertEqual(found["lid"]?["access.power"], "helper")
        XCTAssertNil(found["pick"]?["access.screen"])
    }

    func testTheCoreListPrintsOffForASpotThatIsNotOn() async throws {
        try "#!/bin/sh\nopenspot power lid-closed\n".writeScript(to: core.appendingPathComponent("awake.spot/awake.sh"), toml: "uses = ['power', 'attachment']")
        accesses.set(.helper, to: .denied)

        let answer = try await call(["spot", "list", "--core"], api: api())
        let found = records(answer.output)

        XCTAssertEqual(found["awake"]?["state"], "off")
        XCTAssertEqual(found["awake"]?["uses"], "attachment,power")
        XCTAssertEqual(found["awake"]?["needs"], "helper")
    }

    func testTheLastUseOfAnAdmittedCallShowsInTheListAndSurvivesARestart() async throws {
        let stats = root.appendingPathComponent("stats", isDirectory: true)
        accesses.set(.screen, to: .denied)
        reads.set(trust: .unasked)
        let runs = SpotRuns(clock: clock.value, stats: stats)
        let api = api(runs: runs)
        let shot = Spot(id: "shot", name: "Shot", url: spots.spotFile("shot"), dataName: "shot", uses: [.screen, .clipboard])

        _ = try await call(["window", "frame"], api: api, from: shot, runs: runs)
        let listed = try await call(["spot", "list"], api: api)
        runs.usage.flush()
        let restarted = SpotRuns(clock: clock.value, stats: stats)
        let again = try await call(["spot", "list"], api: self.api(runs: restarted))

        XCTAssertEqual(records(listed.output)["shot"]?["last.screen"], "1970-01-01T00:16:40Z")
        XCTAssertNil(records(listed.output)["shot"]?["last.clipboard"])
        XCTAssertEqual(records(again.output)["shot"]?["last.screen"], "1970-01-01T00:16:40Z")
        XCTAssertEqual(records(again.output)["shot"]?["needs"], "accessibility,screen")
    }

    func testTheCoreListShowsTheLastUseOfEachCoreSpot() async throws {
        let script = core.appendingPathComponent("frame.spot/frame.sh")
        try "#!/bin/sh\nopenspot window frame\n".writeScript(to: script, toml: "title = 'Frame'\nuses = ['screen']")
        reads.set(trust: .unasked)
        let runs = SpotRuns(clock: clock.value, stats: root.appendingPathComponent("stats", isDirectory: true))
        let api = api(runs: runs)
        let frame = Spot(id: "frame", name: "Frame", url: script, dataName: "frame", uses: [.screen])

        _ = try await call(["window", "frame"], api: api, from: frame, runs: runs)
        let listed = records(try await call(["spot", "list", "--core"], api: api).output)

        XCTAssertEqual(listed["frame"]?["last.screen"], "1970-01-01T00:16:40Z")
    }

    func testARefusedUseShowsAsReviewUntilItIsAllowed() async throws {
        let runs = SpotRuns(clock: clock.value, stats: root.appendingPathComponent("stats", isDirectory: true))
        let api = api(runs: runs)
        let plain = Spot(id: "plain", name: "Plain", url: spots.spotFile("plain"), dataName: "plain")
        try #"[{"source":"/x/plain","paths":["plain.spot"],"uses":[],"canDo":[]}]"#.write(to: root.appendingPathComponent("spots.lock"), atomically: true, encoding: .utf8)

        let refused = try await call(["clipboard", "copy"], api: api, from: plain, runs: runs)
        try await wait("the refusal kept") { runs.usage.days(1, at: runs.now()).first?.uses.isEmpty == false }
        let listed = records(try await call(["spot", "list"], api: api).output)
        _ = try await call(["spot", "allow", "plain", "clipboard"], api: api)
        let allowed = records(try await call(["spot", "list"], api: api).output)

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(listed["plain"]?["state"], "review")
        XCTAssertEqual(listed["plain"]?["refused"], "clipboard")
        XCTAssertEqual(allowed["plain"]?["state"], "ready")
        XCTAssertNil(allowed["plain"]?["refused"])
        XCTAssertEqual(allowed["plain"]?["uses"], "clipboard")
    }
}
