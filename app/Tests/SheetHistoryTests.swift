import XCTest
@testable import OpenspotCore

/// Proves the history of sheets: what a push, a step back and a step forward leave at its centre and ahead of it.
final class SheetHistoryTests: XCTestCase {
    private let settings = SheetPage(spot: "settings")
    private let caffeinate = SheetPage(spot: "settings", page: "spot:caffeinate")
    private let notes = SheetPage(spot: "notes")

    func testAPushPutsThePageAtTheCentreAndBackAndForwardMoveAlongTheHistory() {
        var history = SheetHistory()
        history.push(settings)
        history.push(caffeinate)

        XCTAssertEqual(history.current, caffeinate)
        XCTAssertEqual(history.back(), settings)
        XCTAssertEqual(history.ahead, caffeinate)
        XCTAssertNil(history.back())
        XCTAssertEqual(history.forward(), caffeinate)
        XCTAssertNil(history.forward())
        XCTAssertEqual(history.behind, settings)
    }

    func testAPushAfterAStepBackDropsTheSheetsAhead() {
        var history = SheetHistory()
        history.push(settings)
        history.push(caffeinate)
        _ = history.back()

        history.push(notes)

        XCTAssertEqual(history.pages, [settings, notes])
        XCTAssertNil(history.forward())
    }

    func testAPageThatIsAlreadyInTheHistoryMovesToTheTop() {
        var history = SheetHistory()
        history.push(settings)
        history.push(notes)
        history.push(caffeinate)

        history.push(notes)

        XCTAssertEqual(history.pages, [settings, caffeinate, notes])
        XCTAssertEqual(history.current, notes)
    }

    func testThePushOfTheCurrentPageChangesNothing() {
        var history = SheetHistory()
        history.push(settings)

        history.push(settings)

        XCTAssertEqual(history.pages, [settings])
    }

    func testTheOldestPageDropsPastTheLimit() {
        var history = SheetHistory()
        for index in 0...SheetHistory.limit { history.push(SheetPage(spot: "s\(index)")) }

        XCTAssertEqual(history.pages.count, SheetHistory.limit)
        XCTAssertEqual(history.pages.first, SheetPage(spot: "s1"))
        XCTAssertEqual(history.current, SheetPage(spot: "s\(SheetHistory.limit)"))
    }

    func testAClearLeavesNoPage() {
        var history = SheetHistory()
        history.push(settings)

        history.clear()

        XCTAssertNil(history.current)
        XCTAssertTrue(history.pages.isEmpty)
    }

    func testTheRemovalOfASpotDropsItsPagesAndKeepsTheCentreOnAPageThatStays() {
        var history = SheetHistory()
        history.push(notes)
        history.push(settings)
        history.push(caffeinate)

        history.remove(spot: "settings")

        XCTAssertEqual(history.pages, [notes])
        XCTAssertEqual(history.current, notes)
    }
}
