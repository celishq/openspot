import XCTest
@testable import OpenspotCore

@MainActor
final class ToastSizeTests: XCTestCase {
    func testAShortToastIsAsWideAsItsWords() {
        let size = Toast.size { width in CGSize(width: min(120.4, width), height: 20) }

        XCTAssertEqual(size, CGSize(width: 122, height: 20))
    }

    func testLongWordsWrapAtTheWidestToast() {
        let words: CGFloat = 1000
        let size = Toast.size { width in CGSize(width: min(words, width), height: 20 * (words / min(words, width)).rounded(.up)) }

        XCTAssertEqual(size.width, SpotTokens.toastWidest)
        XCTAssertEqual(size.height, 20 * (words / SpotTokens.toastWidest).rounded(.up))
    }

    func testContentThatCannotWrapIsNeverWiderThanTheWidestToast() {
        let size = Toast.size { _ in CGSize(width: 900, height: 40) }

        XCTAssertEqual(size, CGSize(width: SpotTokens.toastWidest, height: 40))
    }

    func testTheWidestToastLeavesTheRoomOfItsShadowInTheWindow() {
        XCTAssertEqual(SpotTokens.toastWidest + 2 * SpotTokens.toastRoom, SpotTokens.toastMaxWidth)
    }
}
