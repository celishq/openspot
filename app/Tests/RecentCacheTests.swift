import XCTest
@testable import OpenspotCore

final class RecentCacheTests: XCTestCase {
    func testAValuePastTheLimitLetsGoOnlyTheLeastRecentlyUsed() {
        var cache = RecentCache<String, Int>(base: 10)
        cache.keep(1, for: "a", cost: 10)
        cache.keep(2, for: "b", cost: 10)
        _ = cache.value(for: "a")
        cache.keep(3, for: "c", cost: 10)
        cache.keep(4, for: "d", cost: 10)

        XCTAssertEqual(cache.value(for: "a"), 1)
        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "c"), 3)
        XCTAssertEqual(cache.value(for: "d"), 4)
        XCTAssertEqual(cache.bytes, 30)
    }

    func test_A40_theLargestValueTwiceFitsBesideTheBase() {
        var cache = RecentCache<String, Int>(base: 30)
        cache.keep(1, for: "card", cost: 10)
        cache.keep(2, for: "dock sides", cost: 100)
        cache.keep(3, for: "dock ends", cost: 100)

        XCTAssertEqual(cache.value(for: "card"), 1)
        XCTAssertEqual(cache.limit, 230)
        XCTAssertEqual(cache.room, 20)
    }
}
