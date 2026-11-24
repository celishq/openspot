import XCTest
@testable import OpenspotCore

final class ToastStackTests: XCTestCase {
    func testANewToastGoesOnTopOfTheOthers() {
        var stack = ToastStack()

        let first = stack.add(spot: "a", kind: .confirm)
        let second = stack.add(spot: "b", kind: .failure)

        XCTAssertEqual(stack.entries.map(\.number), [second.number, first.number])
        XCTAssertEqual(second.dropped, [])
    }

    func testAFourthToastDropsTheOldest() {
        var stack = ToastStack()
        let oldest = stack.add(spot: "a", kind: .confirm).number
        stack.add(spot: "a", kind: .confirm)
        stack.add(spot: "a", kind: .confirm)

        let fourth = stack.add(spot: "a", kind: .confirm)

        XCTAssertEqual(fourth.dropped, [oldest])
        XCTAssertEqual(stack.entries.count, ToastStack.limit)
        XCTAssertFalse(stack.entries.contains { $0.number == oldest })
    }

    func testAWorkToastGivesWayToTheNextToastOfItsSpot() {
        var stack = ToastStack()
        let work = stack.add(spot: "", kind: .work).number
        let other = stack.add(spot: "a", kind: .confirm).number

        let next = stack.add(spot: "", kind: .confirm)

        XCTAssertEqual(next.dropped, [work])
        XCTAssertEqual(stack.entries.map(\.number), [next.number, other])
    }

    func testARemovedToastLeavesTheStack() {
        var stack = ToastStack()
        let first = stack.add(spot: "a", kind: .confirm).number
        let second = stack.add(spot: "a", kind: .confirm).number

        XCTAssertTrue(stack.remove(first))
        XCTAssertFalse(stack.remove(first))
        XCTAssertEqual(stack.entries.map(\.number), [second])
    }

    func testAToastWithTheIdOfOneThatShowsChangesItInPlace() {
        var stack = ToastStack()
        let first = stack.add(spot: "a", kind: .confirm, id: "up")
        let other = stack.add(spot: "a", kind: .confirm)

        let again = stack.add(spot: "a", kind: .confirm, id: "up")

        XCTAssertEqual(again.number, first.number)
        XCTAssertFalse(again.isNew)
        XCTAssertEqual(stack.entries.map(\.number), [other.number, first.number])
    }

    func testTheSameIdOfAnotherSpotIsAnotherToast() {
        var stack = ToastStack()
        stack.add(spot: "a", kind: .confirm, id: "up")

        let other = stack.add(spot: "b", kind: .confirm, id: "up")

        XCTAssertTrue(other.isNew)
        XCTAssertEqual(stack.entries.count, 2)
        XCTAssertEqual(stack.number(of: "up", spot: "b"), other.number)
    }
}
