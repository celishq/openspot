import XCTest
@testable import OpenspotCore

private enum BellCall: NounCall {
    case ring(String)
    case count

    static let noun = CommandNoun("bell", group: .app, guide: "screen", verbs: [
        CommandVerb("ring", "<words>...", "Rings the bell with the words.", rule: CallRule(use: .network, used: "rang a bell", inShow: .changes("rings a bell"))) { words in
            words.none ? nil : Self.ring(words.rest.joined(separator: " "))
        },
        CommandVerb("count", "", "Counts the lines on stdin.", rule: CallRule(flags: .readsInput)) { $0.none ? Self.count : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .ring(let words): { CommandAnswer(output: "rang \(words)\n") }
        case .count: { [input = context.input] in CommandAnswer(output: "\(await input().split(separator: "\n").count)\n") }
        }
    }
}

@MainActor
final class CommandNounTests: XCTestCase {
    private let nouns = CommandNoun.all + [BellCall.noun]
    private var folder: URL!
    private var runs: SpotRuns!
    private var api: CommandAPI!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
        api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: FakeRunningApp(), runs: runs, nouns: nouns)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func ask(_ arguments: [String], from spot: Spot? = nil, input: String = "") async throws -> CommandAnswer {
        let request = CommandRequest(arguments: arguments, folder: folder.path, caller: spot.map { runs.callers.issue(for: $0) })
        return try await XCTUnwrap(api.work(for: request, input: { input }))()
    }

    private func spot(uses: Set<SpotUse>) -> Spot {
        Spot(id: "chime", name: "Chime", url: folder.appendingPathComponent("chime.sh"), dataName: "chime", uses: uses)
    }

    func testANounInOneFolderIsParsedListedAndRun() async throws {
        XCTAssertEqual(CommandLineCall(arguments: ["bell", "ring", "a", "b"], nouns: nouns)?.value as? BellCall, .ring("a b"))
        XCTAssertEqual(CommandLineCall(arguments: ["bell", "ring"], nouns: nouns)?.value as? CallFault, .unknown(["bell", "ring"]))
        XCTAssertEqual(CommandLineCall(arguments: ["bell", "ring", "a"])?.value as? CallFault, .unknown(["bell", "ring", "a"]))
        XCTAssertTrue(CommandLineCall.usage(of: nouns).contains("openspot bell ring <words>...                Rings the bell with the words.\n"))
        XCTAssertFalse(CommandLineCall.usage.contains("openspot bell"))

        let answer = try await ask(["bell", "ring", "hi"])

        XCTAssertEqual(answer.output, "rang hi\n")
    }

    func testARunOfAnotherSpotCountsOnItWithItsCaller() async throws {
        try "#!/bin/sh\necho 'title=hi'\n".writeScript(to: folder.appendingPathComponent("spots/echo.sh"), toml: "title = 'Echo'")
        let caller = Spot(id: "board", name: "Board", url: folder.appendingPathComponent("board.sh"), dataName: "board", uses: [.spots])

        let answer = try await ask(["spot", "run", "echo"], from: caller)

        XCTAssertEqual(answer.output, "title=hi\n", answer.errors)
        try await wait("the run by board") { self.runs.usage.counts["echo"]?.callers == ["board": 1] }
        XCTAssertEqual(runs.usage.counts["echo"]?.runs, 1)
    }

    func testARunThatOpenspotRefusesCountsNothing() async throws {
        let core = folder.appendingPathComponent("core", isDirectory: true)
        try "#!/bin/sh\necho 'title=hi'\n".writeScript(to: core.appendingPathComponent("openspot.spot/keyed.sh"), toml: "title = 'Keyed'\nuses = ['account']")
        api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path, "OPENSPOT_CORE": core.path]), app: FakeRunningApp(), runs: runs, nouns: nouns)
        let caller = Spot(id: "board", name: "Board", url: folder.appendingPathComponent("board.sh"), dataName: "board", uses: [.spots])

        let answer = try await ask(["spot", "run", "openspot/keyed"], from: caller)

        XCTAssertTrue(answer.errors.contains("account key"), answer.errors)
        XCTAssertNil(runs.usage.counts["openspot/keyed"])
    }

    func testTheRuleOfAVerbRefusesItInARead() {
        XCTAssertEqual(
            CommandLineCall(arguments: ["bell", "ring", "hi"], reason: "panel.open", nouns: nouns)?.value as? CallFault,
            .refused("`openspot bell ring` rings a bell, so it cannot run in a show. Run it from a pick or an action.")
        )
        XCTAssertEqual(CommandLineCall(arguments: ["bell", "count"], reason: "panel.open", nouns: nouns)?.value as? BellCall, .count)
    }

    func testTheUseOfAVerbIsAdmittedAndCounted() async throws {
        let answer = try await ask(["bell", "ring", "hi"], from: spot(uses: []))
        try await wait("the count of the use") { self.runs.usage.counts["chime"]?.calls["bell.ring"] == 1 }
        XCTAssertEqual(answer.output, "rang hi\n")

        runs.isCareful = true
        let refused = try await ask(["bell", "ring", "hi"], from: spot(uses: []))
        let declared = try await ask(["bell", "ring", "hi"], from: spot(uses: [.network]))

        XCTAssertEqual(refused.errors, "Careful mode stopped Chime, because it rang a bell without `network` in the `uses` of its spot.toml. Add it, or turn Careful mode off.\n")
        XCTAssertEqual(declared.output, "rang hi\n")
    }

    func testABatchTakesNoBatchInsideIt() async throws {
        let answer = try await ask(["batch"], input: "batch\n")

        XCTAssertEqual(answer.errors, "openspot batch cannot run `batch`, because it does not print data. Run it on its own.\n")
    }

    func testABatchTakesAVerbThatReadsNoInput() async throws {
        let answer = try await ask(["batch"], input: "bell ring a\nbell count\n")

        XCTAssertEqual(answer.output, "rang a\n---\n")
        XCTAssertEqual(answer.errors, "openspot batch cannot run `bell count`, because it does not print data. Run it on its own.\n")
    }

    func testEachVerbOfTheTableIsInTheUsageAndParsesItsOwnForm() {
        for noun in CommandNoun.all {
            for verb in noun.verbs where !verb.about.isEmpty {
                let form = verb.form.replacingOccurrences(of: "<size>", with: "wide").replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<[^>]*>"#, with: "x", options: .regularExpression)
                    .replacingOccurrences(of: "...", with: "")
                    .replacingOccurrences(of: "on|off", with: "on")
                    .replacingOccurrences(of: "frame", with: "0 0 1 1")
                let arguments = [noun.name] + verb.words + form.split(separator: " ").map(String.init)
                let call = CommandLineCall(arguments: arguments, spot: "own")
                XCTAssertNotNil(call, arguments.joined(separator: " "))
                if case .unknown(let words)? = call?.value as? CallFault { XCTFail("the table cannot parse \(words)") }
                XCTAssertTrue(CommandLineCall.usage.contains((["openspot", noun.name] + verb.words).joined(separator: " ")), arguments.joined(separator: " "))
            }
        }
    }
}
