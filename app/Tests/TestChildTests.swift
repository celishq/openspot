import XCTest

final class TestChildTests: XCTestCase {
    func testStopReturnsInAnAsyncTestForAChildThatHasEnded() async throws {
        for _ in 0..<20 {
            let child = try TestChild("/bin/sh", ["-c", "exit 0"])
            try await wait("the end of the child") { kill(child.processIdentifier, 0) != 0 }

            XCTAssertTrue(child.stop())
        }
    }
}
