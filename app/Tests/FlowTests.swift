import XCTest
@testable import OpenspotCore

/// Proves the flow of sheets: what a push, a step back and a step forward leave at its centre and ahead of it.
final class FlowTests: XCTestCase {
    private let settings = FlowSheet(spot: "settings")
    private let caffeinate = FlowSheet(spot: "settings", page: "spot:caffeinate")
    private let notes = FlowSheet(spot: "notes")

    func testAPushPutsThePageAtTheCentreAndBackAndForwardMoveAlongTheHistory() {
        var flow = Flow()
        flow.push(settings)
        flow.push(caffeinate)

        XCTAssertEqual(flow.current, caffeinate)
        XCTAssertEqual(flow.back(), settings)
        XCTAssertEqual(flow.ahead, caffeinate)
        XCTAssertNil(flow.back())
        XCTAssertEqual(flow.forward(), caffeinate)
        XCTAssertNil(flow.forward())
        XCTAssertEqual(flow.behind, settings)
    }

    func testAPushAfterAStepBackDropsTheSheetsAhead() {
        var flow = Flow()
        flow.push(settings)
        flow.push(caffeinate)
        _ = flow.back()

        flow.push(notes)

        XCTAssertEqual(flow.pages, [settings, notes])
        XCTAssertNil(flow.forward())
    }

    func testAPageThatIsAlreadyInTheHistoryMovesToTheTop() {
        var flow = Flow()
        flow.push(settings)
        flow.push(notes)
        flow.push(caffeinate)

        flow.push(notes)

        XCTAssertEqual(flow.pages, [settings, caffeinate, notes])
        XCTAssertEqual(flow.current, notes)
    }

    func testThePushOfTheCurrentPageChangesNothing() {
        var flow = Flow()
        flow.push(settings)

        flow.push(settings)

        XCTAssertEqual(flow.pages, [settings])
    }

    func testTheOldestPageDropsPastTheLimit() {
        var flow = Flow()
        for index in 0...Flow.limit { flow.push(FlowSheet(spot: "s\(index)")) }

        XCTAssertEqual(flow.pages.count, Flow.limit)
        XCTAssertEqual(flow.pages.first, FlowSheet(spot: "s1"))
        XCTAssertEqual(flow.current, FlowSheet(spot: "s\(Flow.limit)"))
    }

    func testAClearLeavesNoPage() {
        var flow = Flow()
        flow.push(settings)

        flow.clear()

        XCTAssertNil(flow.current)
        XCTAssertTrue(flow.pages.isEmpty)
    }

    func testTheRemovalOfASpotDropsItsPagesAndKeepsTheCentreOnAPageThatStays() {
        var flow = Flow()
        flow.push(notes)
        flow.push(settings)
        flow.push(caffeinate)

        flow.remove(spot: "settings")

        XCTAssertEqual(flow.pages, [notes])
        XCTAssertEqual(flow.current, notes)
    }
}
