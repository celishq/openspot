import XCTest

/// Proves that a test can end its child and wait for it from an async test, after the child has already ended, where
/// `waitUntilExit` hung within 20 rounds.
final class TestChildTests: XCTestCase {
    func testStopReturnsInAnAsyncTestForAChildThatHasEnded() async throws {
        for _ in 0..<20 {
            let child = try TestChild("/bin/sh", ["-c", "exit 0"])
            try await Task.sleep(for: .milliseconds(100))

            XCTAssertTrue(child.stop())
        }
    }
}
