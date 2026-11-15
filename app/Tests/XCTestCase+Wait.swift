import XCTest

extension XCTestCase {
    @nonobjc func wait(_ fact: String, seconds: Double = 60, isolation: isolated (any Actor)? = #isolation, until holds: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let end = ContinuousClock.now + .seconds(seconds)
        while !holds() {
            guard ContinuousClock.now < end else { return XCTFail("waited for \(fact)", file: file, line: line) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
