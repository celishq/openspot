import XCTest
@testable import OpenspotCore

/// Proves when the app shows in the Dock and in Command-Tab: while at least one window that the person works in is open.
final class WorkWindowsTests: XCTestCase {
    func testTheAppIsRegularWhileAWindowIsOpenAndAMenuBarAppAfterTheLastCloses() {
        var windows = WorkWindows()

        XCTAssertFalse(windows.isRegular)
        windows.open()
        windows.open()
        XCTAssertTrue(windows.isRegular)
        windows.close()
        XCTAssertTrue(windows.isRegular)
        windows.close()
        XCTAssertFalse(windows.isRegular)
        windows.close()
        XCTAssertFalse(windows.isRegular)
    }
}
