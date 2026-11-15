import XCTest
@testable import OpenspotCore

final class UnlockPassTests: XCTestCase {
    func testAnUnlockCoversTheSameActForFiveMinutesAndNoOtherAct() {
        let start = Date(timeIntervalSince1970: 1000)
        var pass = UnlockPass()

        pass.pass("sign your spot", at: start)

        XCTAssertTrue(pass.covers("sign your spot", at: start.addingTimeInterval(299)))
        XCTAssertFalse(pass.covers("sign your spot", at: start.addingTimeInterval(300)))
        XCTAssertFalse(pass.covers("sign out of your account", at: start.addingTimeInterval(1)))
        XCTAssertFalse(UnlockPass().covers("sign your spot", at: start))
    }
}
