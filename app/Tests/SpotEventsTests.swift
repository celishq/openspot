import XCTest
@testable import OpenspotCore

/// The rules of events: a spot lists them in its `read`, and each one reads the wanted spots that list it (B1-B5).
@MainActor
final class SpotEventsTests: SpotRunsCase {
    private var reasons: String {
        "echo \"$OPENSPOT_REASON ${OPENSPOT_VALUE-none}\" >> '\(path("reasons"))'"
    }

    func testAReadTakesEventNamesBesideItsMoments() {
        XCTAssertEqual(SpotRead(text: "panel,music.track,clipboard,app.front,60")?.moments, [.panel, .event("music.track"), .event("clipboard"), .event("app.front"), .every(60)])
        XCTAssertNil(SpotRead(text: "music"))
        XCTAssertNil(SpotRead(text: "1.5"))
        XCTAssertNil(SpotRead(text: "music."))
        XCTAssertNil(SpotRead(text: "music track.x"))
    }

    func testAnEventReadsEachWantedSpotThatListsItWithItsNameAndValue() async throws {
        try script("listens", header: "read=panel,music.track", log: "listens", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        try script("other", header: "read=panel,other.event", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.panelOpened()
        try await wait("the panel reads") { self.log("listens") == ["read"] && self.log("other") == ["read"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read") { self.log("reasons") == ["panel none", "music.track Song"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), ["read"])
    }

    func testAnEventWithNoValueGivesNone() async throws {
        menuBar.insert("script")
        try script(header: "read=clipboard", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        runs.raise(.named("clipboard", value: nil))

        try await wait("the event read") { self.log("reasons") == ["clipboard none"] }
    }

    func testAnEventReadsASpotOnlyWhileSomethingWantsIt() async throws {
        menuBar.insert("wanted")
        try script("wanted", header: "read=music.track", log: "wanted", "printf 'text=t\\ntitle=T\\n'")
        try script("unwanted", header: "read=music.track", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the read of the wanted spot") { self.log("wanted") == ["read"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("unwanted"), [])
    }

    func testASpotThatListsAnEventCanShowInTheMenuBar() throws {
        try script(header: "read=app.front", "printf 'text=t\\ntitle=T\\n'")
        XCTAssertTrue(try sheet().command.canShowInMenuBar)
    }
}
