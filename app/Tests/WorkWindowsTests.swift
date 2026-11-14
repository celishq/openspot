import XCTest
@testable import OpenspotCore

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
