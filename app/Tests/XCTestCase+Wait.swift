import XCTest

extension XCTestCase {
    @nonobjc func wait(_ fact: String, seconds: Double = 10, isolation: isolated (any Actor)? = #isolation, until holds: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let end = ContinuousClock.now + .seconds(seconds)
        while !holds() {
            guard ContinuousClock.now < end else { return XCTFail("waited for \(fact)", file: file, line: line) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor func pass(_ seconds: TimeInterval, on clock: FakeClock, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await wait("a wait of \(seconds) s", until: { clock.isWaiting(for: seconds) }, file: file, line: line)
        clock.advance(by: seconds)
    }
}
