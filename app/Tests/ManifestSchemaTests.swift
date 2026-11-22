import XCTest
@testable import OpenspotCore

final class ManifestSchemaTests: XCTestCase {
    private var root: URL!

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_SPOTS": root.appendingPathComponent("spots").path, "OPENSPOT_CORE": root.appendingPathComponent("core").path]
    }

    override func setUpWithError() throws {
        root = try temporaryFolder()
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: Mac(), places: .test(environment), app: FakeRunningApp(), rates: .offline).work(for: call, request: .test(arguments, in: environment), input: { "" }))
        return await work()
    }

    func testTheRepoCopyOfTheSchemaIsTheOneThatOpenspotSchemaPrints() async throws {
        let copy = try String(contentsOf: RepoDoc.repo.appendingPathComponent(ManifestSchema.repoPath), encoding: .utf8)

        let printed = try await answer(["schema"])

        XCTAssertEqual(printed.code, 0, printed.errors)
        XCTAssertEqual(printed.output, ManifestSchema.text)
        XCTAssertEqual(copy, ManifestSchema.text, "Run `openspot schema > \(ManifestSchema.repoPath)` with a Debug build")
    }

    func testTheSchemaNamesEachKeyAndEachTypeThatTheParserTakes() throws {
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(ManifestSchema.text.utf8)) as? [String: Any])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let types = try XCTUnwrap(((schema["$defs"] as? [String: Any])?["type"] as? [String: Any])?["enum"] as? [String])

        XCTAssertEqual(Set(properties.keys), Manifest.keys.union(Manifest.tables).union(["scripts"]))
        XCTAssertEqual(Set(types), Set(ValueType.Kind.allCases.flatMap { [$0.rawValue, "[\($0.rawValue)]"] }))
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
    }

    func testEachNounCommandDeclaresItsInputsFromItsUsage() throws {
        let timer = try XCTUnwrap(CommandNoun.all.first { $0.name == "timer" }?.verbs.first { $0.words == ["add"] })
        let stats = try XCTUnwrap(CommandNoun.all.first { $0.name == "spot" }?.verbs.first { $0.words == ["stats"] })

        XCTAssertEqual(timer.inputs["required"] as? [String], ["time"])
        XCTAssertEqual(Set((timer.inputs["properties"] as? [String: Any])?.keys ?? [:].keys), ["time", "action", "input"])
        let options = try XCTUnwrap(stats.inputs["properties"] as? [String: [String: Any]])
        XCTAssertEqual(options["days"]?["type"] as? String, "string")
        XCTAssertEqual(options["json"]?["type"] as? String, "boolean")
        XCTAssertEqual(options["openmetrics"]?["type"] as? String, "boolean")
    }

    func testSpotActionsListsEachActionOfASpotAndEachCommandOfItsUses() async throws {
        try "#!/bin/sh\n".writeScript(to: root.appendingPathComponent("spots").spotFile("snooze"), toml: """
        uses = ["timer"]

        [actions.snooze]
        title = "Snooze Tab"
        inputs.url = { type = "url", required = true }
        outputs.until = "date"
        """)

        let answer = try await answer(["spot", "actions", "snooze"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        let spots = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]])
        let spot = try XCTUnwrap(spots.first)
        XCTAssertEqual(spot["spot"] as? String, "snooze")
        let action = try XCTUnwrap((spot["actions"] as? [[String: Any]])?.first)
        XCTAssertEqual(action["name"] as? String, "snooze")
        XCTAssertEqual((action["inputs"] as? [String: Any])?["required"] as? [String], ["url"])
        XCTAssertEqual((((action["inputs"] as? [String: Any])?["properties"] as? [String: Any])?["url"] as? [String: Any])?["format"] as? String, "uri")
        XCTAssertNotNil(((action["outputs"] as? [String: Any])?["properties"] as? [String: Any])?["until"])
        let commands = try XCTUnwrap(spot["commands"] as? [[String: Any]])
        XCTAssertTrue(commands.contains { $0["name"] as? String == "timer add" }, "\(commands.map { $0["name"] ?? "" })")
        XCTAssertFalse(commands.contains { ($0["name"] as? String)?.hasPrefix("clipboard") == true })
    }

    func testSpotActionsFailsForASpotThatDoesNotLoad() async throws {
        let answer = try await answer(["spot", "actions", "none"])

        XCTAssertEqual(answer.code, 1)
    }
}
