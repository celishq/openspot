import XCTest
@testable import OpenspotCore

final class RecentCacheTests: XCTestCase {
    func testAValuePastTheLimitLetsGoOnlyTheLeastRecentlyUsed() {
        var cache = RecentCache<String, Int>(limit: 30)
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

    func testALargeValueRaisesNoLimit() {
        var cache = RecentCache<String, Int>(limit: 30)
        cache.keep(1, for: "dock", cost: 100)
        cache.keep(2, for: "card", cost: 10)

        XCTAssertNil(cache.value(for: "dock"))
        XCTAssertEqual(cache.value(for: "card"), 2)
        XCTAssertEqual(cache.bytes, 10)
    }
}
