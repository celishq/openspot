import XCTest
@testable import OpenspotCore

/// Proves the places where the playground shows a spot: its sheet opens it, its card reads it as the open panel does, and
/// the main search asks it the text, again after each edit. Each place names the `on` line that a spot lacks for it.
@MainActor
final class PlaygroundPlaceTests: SpotRunsCase {
    private var reasons: String {
        "echo \"$OPENSPOT_REASON ${OPENSPOT_VALUE-none}\" >> '\(path("reasons"))'"
    }

    func testTheSheetOpensTheSpot() async throws {
        try script(header: "on=sheet.open", "\(reasons)\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        PlaygroundPlace.sheet.show(sheet, query: "")

        try await wait("the read of the sheet") { self.log("reasons") == ["sheet.open none"] }
        XCTAssertTrue(sheet.isOpen)
    }

    func testTheCardReadsTheSpotAsTheOpenPanelDoesAndOpensNoSheet() async throws {
        try script(header: "on=panel.open", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        let sheet = try sheet()

        PlaygroundPlace.card.show(sheet, query: "")

        try await wait("the read of the panel") { self.log("reasons") == ["panel.open none"] }
        XCTAssertFalse(sheet.isOpen)
    }

    func testTheSearchAsksTheTextAgainAfterAnEdit() async throws {
        try script(header: "on=search.text ^[0-9]", "\(reasons)\nprintf 'row=%s\\ntitle=Is %s\\n' \"$OPENSPOT_VALUE\" \"$OPENSPOT_VALUE\"")
        let sheet = try sheet()

        PlaygroundPlace.search.show(sheet, query: "12")
        try await wait("the answer") { sheet.answers.map(\.run) == ["12"] }
        PlaygroundPlace.search.show(sheet, query: "12")

        try await wait("the second answer") { self.log("reasons").count == 2 }
        XCTAssertEqual(log("reasons"), ["search.text 12", "search.text 12"])
        XCTAssertFalse(sheet.isOpen)
    }

    func testTheSearchTypesInTheMainSearchAndTheSheetInItsOwn() async throws {
        try script(header: "on=search.text ^[0-9]\non=sheet.text", "\(reasons)\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        PlaygroundPlace.search.type("7", in: sheet)
        try await wait("the answer") { self.log("reasons") == ["search.text 7"] }

        XCTAssertFalse(sheet.isOpen)
    }

    func testEachPlaceNamesTheLineThatTheSpotLacks() throws {
        try script("bare", header: "title=Bare")
        try script("card", header: "on=panel.open")
        try script("clock", header: "on=clock.60")
        try script("answer", header: "on=search.text ^[0-9]")
        _ = try scanned()
        let spot = { (id: String) in try XCTUnwrap(self.runs.sheets[id]).spot }

        XCTAssertNil(PlaygroundPlace.sheet.lack(of: try spot("bare")))
        XCTAssertEqual(PlaygroundPlace.card.lack(of: try spot("bare")), "The panel reads a card with on=panel.open or on=clock.<seconds>.")
        XCTAssertNil(PlaygroundPlace.card.lack(of: try spot("card")))
        XCTAssertNil(PlaygroundPlace.card.lack(of: try spot("clock")))
        XCTAssertEqual(PlaygroundPlace.search.lack(of: try spot("card")), "The main search asks a spot with on=search.text <pattern>, such as on=search.text ^[0-9].")
        XCTAssertNil(PlaygroundPlace.search.lack(of: try spot("answer")))
    }
}
