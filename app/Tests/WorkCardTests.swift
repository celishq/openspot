import XCTest
@testable import OpenspotCore

@MainActor
final class WorkCardTests: SpotRunsCase {
    private func touch(_ name: String) {
        FileManager.default.createFile(atPath: path(name), contents: nil)
    }

    private func until(_ name: String) -> String {
        "while [ ! -e '\(path(name))' ]; do sleep 0.02; done"
    }

    func testTheCardShowsTheTitleAndFillOfItsCallOnlyAfterItsPause() async throws {
        try script(body: "printf 'frame=\\nprogress=0.5\\ntitle=Getting ready\\n---\\n'\nsleep 30")
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 0.9
        XCTAssertNil(runs.workCard)

        time += 0.1
        try await wait("the card") { self.runs.workCard != nil }
        XCTAssertEqual(runs.workCard?.spot, "script")
        XCTAssertEqual(runs.workCard?.words, "Getting ready")
        let fill = try XCTUnwrap(runs.workCard?.fill)
        XCTAssertEqual(fill.base, 0.5)
        XCTAssertGreaterThan(fill.value(at: time.addingTimeInterval(5)), fill.value(at: time))
    }

    func testACallWithNoTitleSetsUpItsSpot() async throws {
        try script(body: "sleep 30")
        let sheet = try sheet()

        sheet.pressCard()
        time += 1

        try await wait("the card") { self.runs.workCard != nil }
        XCTAssertEqual(runs.workCard?.words, "Setting up \(sheet.spot.name)")
        XCTAssertEqual(runs.workCard?.fill.value(at: try XCTUnwrap(sheet.calls.first).started), 0)
    }

    func testTheCardFillsWhenItsCallEndsAndThenLeaves() async throws {
        try script(body: until("end"))
        let sheet = try sheet()
        sheet.pressCard()
        time += 1
        try await wait("the card") { self.runs.workCard != nil }

        touch("end")

        try await wait("the end") { sheet.calls.isEmpty }
        XCTAssertEqual(runs.workCard?.spot, "script")
        XCTAssertEqual(runs.workCard?.fill, .full)
        time += 1
        try await wait("the card leaves") { self.runs.workCard == nil }
    }

    func testTheCardFillsWhenItsCallDrawsAPictureAndThenLeaves() async throws {
        try script(body: "printf 'frame=\\ntitle=Getting ready\\n---\\n'\n\(until("draw"))\nprintf 'frame=\\n\\nitem=a\\ntitle=A\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 1
        try await wait("the card") { self.runs.workCard?.words == "Getting ready" }

        touch("draw")

        try await wait("the picture") { self.runs.workCard?.fill == .full }
        XCTAssertEqual(sheet.calls.count, 1)
        time += 1
        try await wait("the card leaves") { self.runs.workCard == nil }
    }

    func testNoCardShowsForTheSpotThePanelShows() async throws {
        try script(body: "[ \"$1\" = read ] || sleep 30")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        sheet.pressCard()
        time += 1
        try await wait("the shown work") { !sheet.acts.isEmpty }
        XCTAssertNil(runs.workCard)

        sheet.close()
        XCTAssertNil(runs.workCard)

        runs.panelClosed()
        XCTAssertEqual(runs.workCard?.spot, "script")
    }

    func testTheCardShowsTheOldestWork() async throws {
        try script("a", "sleep 30")
        try script("z", "sleep 30")
        _ = try scanned()
        let a = try XCTUnwrap(runs.sheets["a"])
        let z = try XCTUnwrap(runs.sheets["z"])

        z.pressCard()
        time += 1
        a.pressCard()
        try await wait("the card of z") { self.runs.workCard?.spot == "z" }

        time += 1
        try await wait("both shown") { self.runs.acts.count == 2 }
        XCTAssertEqual(runs.workCard?.spot, "z")

        z.stop(try XCTUnwrap(z.calls.first))
        XCTAssertEqual(runs.workCard?.spot, "a")
    }

    func testAStoppedCallLeavesTheCardAtOnce() async throws {
        try script(body: "sleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        time += 1
        try await wait("the card") { self.runs.workCard != nil }

        sheet.stop(try XCTUnwrap(sheet.calls.first))

        XCTAssertNil(runs.workCard)
    }

    func testACallPastItsHoldMovesFromTheCardIntoAToastUntilItEnds() async throws {
        try script(body: "printf 'frame=\\ntitle=Building\\n---\\n'\n" + until("end"))
        let sheet = try sheet()
        var told: [[Work]] = []
        runs.onToasted = { told.append($0) }
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 1
        try await wait("the card") { self.runs.workCard != nil }
        XCTAssertTrue(runs.toasted.isEmpty)

        time += SpotRuns.cardHold

        try await wait("the toast") { self.runs.toasted.first?.words == "Building" }
        XCTAssertNil(runs.workCard)
        XCTAssertEqual(told.last?.map(\.spot), [sheet.spot.id])
        touch("end")
        try await wait("the end") { self.runs.toasted.isEmpty }
        XCTAssertNil(runs.workCard)
        XCTAssertEqual(told.last?.isEmpty, true)
    }

    func testNoToastShowsForTheSpotThePanelShowsPastItsHold() async throws {
        try script(body: "printf 'frame=\\ntitle=Building\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }

        time += 1 + SpotRuns.cardHold

        try await wait("the act") { !self.runs.acts.isEmpty }
        XCTAssertTrue(runs.toasted.isEmpty)
    }
}
