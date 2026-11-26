import XCTest
@testable import OpenspotCore

@MainActor
final class PeekVideoTests: PanelCase {
    private let peekKey = ActionKey(name: "p", isCommand: true)

    private func openVideos() async throws {
        try script("clips", toml: "title = 'Clips'\n\n[on]\n\"sheet.open\" = true", "printf 'item=a\\ntitle=A\\nfile=/tmp/a.mov\\n\\nitem=b\\ntitle=B\\nfile=/tmp/b.mp4\\n\\nitem=c\\ntitle=C\\ntext=words\\n'")
        await model.reload()
        model.press("clips")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    private func titles() throws -> [String] {
        model.actionMenu(on: try XCTUnwrap(model.target))?.rows.map(\.title) ?? []
    }

    func testAVideoPeeksAsAVideoThatPlaysOnlyOnceThePaneHasGrown() async throws {
        try await openVideos()

        _ = model.handleKey(peekKey)

        XCTAssertEqual(model.peek?.look, .video("/tmp/a.mov"))
        XCTAssertFalse(model.peekPlays)
        try await wait("the grown pane") { self.model.peekPlays }
    }

    func testTheActionsMenuPausesAndPlaysTheVideo() async throws {
        try await openVideos()
        _ = model.handleKey(peekKey)
        try await wait("the grown pane") { self.model.peekPlays }
        XCTAssertTrue(try titles().contains("Pause"))

        model.run(.playback, on: try XCTUnwrap(model.target))

        XCTAssertFalse(model.peekPlays)
        XCTAssertTrue(try titles().contains("Play"))
        model.run(.playback, on: try XCTUnwrap(model.target))
        XCTAssertTrue(model.peekPlays)
    }

    func testTheNextVideoPlaysAgainAfterAPause() async throws {
        try await openVideos()
        _ = model.handleKey(peekKey)
        try await wait("the grown pane") { self.model.peekPlays }
        model.run(.playback, on: try XCTUnwrap(model.target))

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(model.peek?.look, .video("/tmp/b.mp4"))
        XCTAssertTrue(model.peekPlays)
    }

    func testARowThatIsNoVideoOrAClosedPeekOffersNoPlayback() async throws {
        try await openVideos()
        XCTAssertFalse(try titles().contains { $0 == "Play" || $0 == "Pause" })

        _ = model.handleKey(peekKey)
        _ = model.handleSearchKey(ActionKey(name: "down"))
        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertFalse(try titles().contains { $0 == "Play" || $0 == "Pause" })
        XCTAssertFalse(model.peekPlays)
    }

    func testHidingThePanelStopsTheVideo() async throws {
        try await openVideos()
        _ = model.handleKey(peekKey)
        try await wait("the grown pane") { self.model.peekPlays }

        model.panelWillHide()

        XCTAssertFalse(model.peekPlays)
    }
}
