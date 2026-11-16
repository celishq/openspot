import XCTest
@testable import OpenspotCore

final class CommandHelpTests: XCTestCase {
    private var folder: URL!
    private var api: CommandAPI!

    override func setUpWithError() throws {
        folder = try temporaryFolder()
        try "# Openspot guide\n\n## Show a list\n\nPrint rows.\n\n```sh\n# title=List\n## not a topic\n```\n\n### Rows\n\nOne per item.\n\n## Add buttons\n\nPrint buttons.\n"
            .write(to: folder.appendingPathComponent("GUIDE.md"), atomically: true, encoding: .utf8)
        api = CommandAPI(mac: Mac(guide: folder.appendingPathComponent("GUIDE.md")), places: .test(["OPENSPOT_CONFIG": folder.path]), rates: .offline)
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        try await XCTUnwrap(api.work(for: .test(arguments), input: { "" }))()
    }

    func testANounWithNoVerbPrintsOnlyItsOwnVerbsWithCode2() async throws {
        let answer = try await answer(["spot"])

        XCTAssertTrue(answer.errors.hasPrefix("openspot cannot do this: spot\n`openspot spot` needs a verb.\n\nopenspot spot new"), answer.errors)
        XCTAssertTrue(answer.errors.contains("openspot spot run <id>"))
        XCTAssertFalse(answer.errors.contains("openspot clipboard"))
        XCTAssertEqual(answer.code, 2)
    }

    func testAVerbWithWrongWordsPrintsOnlyThatVerb() async throws {
        let answer = try await answer(["spot", "run"])

        XCTAssertTrue(answer.errors.hasPrefix("openspot cannot do this: spot run\n\nopenspot spot run <id>"), answer.errors)
        XCTAssertFalse(answer.errors.contains("openspot spot new"))
        XCTAssertEqual(answer.code, 2)
    }

    func testAWordCloseToANounOrAVerbNamesTheCommandItMeant() async throws {
        let noun = try await answer(["spots", "list"])
        let verb = try await answer(["spot", "lst"])
        let far = try await answer(["xyzzy"])

        XCTAssertTrue(noun.errors.hasPrefix("openspot cannot do this: spots list\nDid you mean `openspot spot list`?\n\nopenspot spot new"), noun.errors)
        XCTAssertTrue(verb.errors.hasPrefix("openspot cannot do this: spot lst\nDid you mean `openspot spot list`?\n\n"), verb.errors)
        XCTAssertEqual(far.errors, "openspot cannot do this: xyzzy\nRun `openspot help` to see each command.\n")
        XCTAssertEqual(far.code, 2)
    }

    func testHelpAfterANounOrAVerbPrintsItsHelp() async throws {
        let noun = try await answer(["spot", "--help"])
        let verb = try await answer(["spot", "run", "--help"])
        let short = try await answer(["clipboard", "copy", "-h"])

        XCTAssertTrue(noun.output.hasPrefix("openspot spot new"), noun.output)
        XCTAssertTrue(noun.output.contains("openspot spot run"))
        XCTAssertTrue(verb.output.hasPrefix("openspot spot run <id>"), verb.output)
        XCTAssertFalse(verb.output.contains("openspot spot new"))
        XCTAssertTrue(short.output.hasPrefix("openspot clipboard copy"), short.output)
        XCTAssertEqual([noun.code, verb.code, short.code], [0, 0, 0])
    }

    func testHelpOfANounPrintsItsVerbsThenItsGuide() {
        XCTAssertEqual(CommandLineCall(arguments: ["help", "spot"])?.value as? HelpCall, .noun("spot", verb: []))
        XCTAssertEqual(CommandLineCall(arguments: ["help", "screen"])?.value as? HelpCall, .noun("screen", verb: []))
        XCTAssertEqual(CommandLineCall(arguments: ["help", "spot", "run"])?.value as? HelpCall, .noun("spot", verb: ["run"]))
    }

    func testTheVersionNeedsNoApp() async throws {
        let long = try await answer(["--version"])
        let word = try await answer(["version"])

        XCTAssertEqual(long.output, word.output)
        XCTAssertTrue(long.output.hasSuffix("\n"))
        XCTAssertEqual(long.code, 0)
        XCTAssertFalse(CommandLineCall(arguments: ["version"])?.rule.flags.contains(.needsApp) ?? true)
    }

    func testTheFlagsAboutTheCommandTakeNoOtherWords() {
        XCTAssertEqual(CommandLineCall(arguments: ["--version", "foo"])?.value as? CallFault, .unknown("--version foo"))
        XCTAssertEqual(CommandLineCall(arguments: ["help", "--help"])?.value as? HelpCall, .list)
        XCTAssertEqual(CommandLineCall(arguments: ["--help", "spot"])?.value as? HelpCall, .noun("spot", verb: []))
    }

    func testAnUnknownLongFlagIsAFaultAndNeverStartsTheAppWindow() {
        XCTAssertEqual(CommandLineCall(arguments: ["--frobnicate"])?.value as? CallFault, .unknown("--frobnicate"))
        XCTAssertNil(CommandLineCall(arguments: ["-NSDocumentRevisionsDebugMode", "YES"]))
    }

    func testTheListGroupsEachNounUnderTheTaskItServes() {
        let usage = CommandLineCall.usage
        let headings = ["Start here", "Build a spot", "Ask the Mac", "Run Openspot"]
        let places = headings.map { usage.range(of: "\($0)\n\n")?.lowerBound }

        XCTAssertTrue(usage.hasPrefix("Start here\n\nopenspot guide"), String(usage.prefix(80)))
        XCTAssertEqual(places.compactMap { $0 }.count, 4)
        XCTAssertEqual(places.compactMap { $0 }, places.compactMap { $0 }.sorted())
        XCTAssertLessThan(usage.range(of: "Build a spot")!.lowerBound, usage.range(of: "openspot spot new")!.lowerBound)
        XCTAssertLessThan(usage.range(of: "Ask the Mac")!.lowerBound, usage.range(of: "openspot clipboard copy")!.lowerBound)
        XCTAssertLessThan(usage.range(of: "Run Openspot")!.lowerBound, usage.range(of: "openspot app status")!.lowerBound)
    }

    func testHelpAsJSONListsEachVerbWithItsEffect() async throws {
        let answer = try await answer(["help", "--json"])
        let entries = try JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]] ?? []
        let copy = entries.first { $0["command"] as? String == "openspot clipboard copy" }
        let show = entries.first { $0["command"] as? String == "openspot spot open" }

        XCTAssertEqual(copy?["form"] as? String, "[file]")
        XCTAssertEqual(copy?["group"] as? String, "Ask the Mac")
        XCTAssertEqual(copy?["effect"] as? String, "changes")
        XCTAssertEqual(show?["needsApp"] as? Bool, true)
        XCTAssertFalse(entries.contains { ($0["command"] as? String)?.hasPrefix("openspot helper") == true })
        XCTAssertEqual(answer.code, 0)
    }

    func testTheGuidePrintsOneTopicOrTheListOfTopics() async throws {
        let topics = try await answer(["guide", "--topics"])
        let topic = try await answer(["guide", "show-a-list"])
        let missing = try await answer(["guide", "show-list"])

        XCTAssertEqual(topics.output, "show-a-list    Show a list\nadd-buttons    Add buttons\n")
        XCTAssertEqual(topic.output, "## Show a list\n\nPrint rows.\n\n```sh\n# title=List\n## not a topic\n```\n\n### Rows\n\nOne per item.\n")
        XCTAssertEqual(missing.errors, "The guide has no topic show-list. Did you mean `openspot guide show-a-list`? Run `openspot guide --topics` to see each topic.\n")
        XCTAssertEqual(missing.code, 2)
    }

    func testAWordOfTheGuideFindsEachTopicThatNamesIt() async throws {
        let one = try await answer(["guide", "buttons"])
        let many = try await answer(["guide", "print"])

        XCTAssertEqual(one.output, "## Add buttons\n\nPrint buttons.\n")
        XCTAssertEqual(many.output, "show-a-list    Show a list\nadd-buttons    Add buttons\n")
        XCTAssertEqual(many.code, 0)
    }
}
