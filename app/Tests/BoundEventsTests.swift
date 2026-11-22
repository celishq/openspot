import XCTest
@testable import OpenspotCore

@MainActor
final class BoundEventsTests: SpotRunsCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
    }

    private func picker(_ words: String) throws {
        try script("picker", toml: "\(TestSpot.command)\n[events.picked]\nuntil = { type = 'date', required = true }\nnote = 'text'", log: "picker-log", """
        '\(client.path)' \(words) 2> '\(path("errors"))'; echo $? >> '\(path("done"))'
        """)
    }

    private func listener(_ name: String, on key: String) throws {
        try script(name, toml: "[bindings]\npicker = { spot = 'picker' }\n[on]\n\"\(key)\" = true", log: "\(name)-log", """
        printf '%s %s\\n' "$1" "$(grep '^input\\.' | tr '\\n' ' ')" >> '\(path("heard"))'
        """)
    }

    private func press() async throws {
        _ = try scanned()
        let sheet = try XCTUnwrap(runs.sheets["picker"])
        sheet.pressCard()
        try await wait("the end of the emit") { self.log("done").count == 1 }
        try await allEnded()
        try await wait("the end of the call in the sheet") { sheet.calls.isEmpty }
    }

    func testAnEmitCallsTheHandlerOfEachSpotThatBindsTheEmitterAndListensToTheEvent() async throws {
        try picker("emit picked until=2026-11-23 note=soon")
        try listener("snooze", on: "picker.picked")
        try script("other", toml: "[on]\nevery = 600", log: "other-log", "printf '%s\\n' \"$1\" >> '\(path("heard"))'")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        try await wait("the call of the listener") { self.log("heard").count == 1 }
        XCTAssertEqual(log("heard"), ["picker.picked input.until=2026-11-23 input.note=soon "])
    }

    func testAnEmitOfAnUndeclaredEventOrAWrongValueExits2AndCallsNoSpot() async throws {
        for (words, line) in [
            ("emit chosen until=2026-11-23", "Picker has no event chosen. Declare it in [events.chosen] of its spot.toml."),
            ("emit picked until=soon", "picked cannot be sent: until takes a date, such as 2026-11-22 or 2026-11-22T09:00:00Z, and got soon."),
            ("emit picked note=x", "picked needs until, which is a date, such as 2026-11-22 or 2026-11-22T09:00:00Z."),
            ("emit picked until=2026-11-23 colour=red", "picked has no value colour. Its values are: until, note.")
        ] {
            try? FileManager.default.removeItem(atPath: path("done"))
            try picker(words)
            try listener("snooze", on: "picker.picked")

            try await press()

            XCTAssertEqual(log("done"), ["2"], words)
            XCTAssertEqual(log("errors"), [line], words)
        }
        try await pause(0.3)
        XCTAssertEqual(log("heard"), [])
    }
}
