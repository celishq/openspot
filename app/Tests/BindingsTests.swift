import XCTest
@testable import OpenspotCore

@MainActor
final class BindingsTests: SpotRunsCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
    }

    private func picker(_ body: String = "") throws {
        try script("picker", toml: "[actions.pick]\ninputs.when = 'text'\noutputs.until = 'text'", log: "picker-log", """
        case "$1" in
          pick) w=$(sed -n 's/^input.when=//p'); echo "out.until=$w-later" ;;
        esac
        \(body)
        """)
    }

    private func asker(binds: String = "picker = { spot = 'picker' }", _ words: String) throws {
        try script("asker", toml: "\(TestSpot.command)\n[bindings]\n\(binds)", log: "asker-log", "'\(client.path)' \(words) > '\(path("out"))' 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")
    }

    private func press() async throws {
        _ = try scanned()
        try XCTUnwrap(runs.sheets["asker"]).pressCard()
        try await wait("the end of the run") { self.log("done").count == 1 }
    }

    func testABindingIsReadAndAWrongOneFailsTheLoadWithALineThatNamesIt() throws {
        let spots = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("snooze"), toml: "[bindings]\npicker = { spot = 'time-picker' }")
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("broken"), toml: "[bindings]\npicker = { id = 'time-picker' }")

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots.first { $0.id == "snooze" }?.bindings.map(\.line), ["picker: time-picker"])
        XCTAssertEqual(scan.refused.map(\.reason), ["Broken cannot load: spot.toml: [bindings] picker has an unknown key: id. Use spot."])
    }

    func testARunThroughABindingThatTheSpotDoesNotDeclareExits2() async throws {
        try picker()
        try asker("run nope.pick when=now")

        try await press()

        XCTAssertEqual(log("done"), ["2"])
        XCTAssertEqual(log("errors"), ["Asker has no binding nope. Add it to the [bindings] of its spot.toml, such as nope = { spot = \"<id>\" }."])
    }

    func testARunThroughABindingToASpotThatIsNotInstalledFailsWithALineThatNamesIt() async throws {
        try asker(binds: "picker = { spot = 'time-picker' }", "run picker.pick when=now")

        try await press()

        XCTAssertEqual(log("done"), ["1"])
        XCTAssertEqual(log("errors"), ["Asker binds picker to the spot time-picker, which is not installed. Install time-picker, or remove picker from the [bindings] of its spot.toml."])
    }

    func testARunThatTheBoundSpotAnswersAtOncePrintsItsValues() async throws {
        try picker()
        try asker("run picker.pick when=now")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(log("out"), ["out.until=now-later"])
        XCTAssertEqual(log("picker-log"), ["pick"])
    }

    func testARunWithAnInputThatTheActionDoesNotDeclareExits2AndCallsNothing() async throws {
        try picker()
        try asker("run picker.pick count=3")

        try await press()

        XCTAssertEqual(log("done"), ["2"])
        XCTAssertEqual(log("errors"), ["pick has no input count. Its inputs are: when."])
        XCTAssertEqual(log("picker-log"), [])
    }
}
