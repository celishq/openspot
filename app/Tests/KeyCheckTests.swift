import XCTest
@testable import OpenspotCore

final class KeyCheckTests: XCTestCase {
    func testAFreeKeyAndATakenKey() throws {
        let space = try XCTUnwrap(Shortcut(code: 49, modifiers: .command))
        let free = try XCTUnwrap(Shortcut(code: 49, modifiers: .option))
        let check = KeyCheck(taken: [TakenKey(shortcut: space, owner: "Spotlight")])
        XCTAssertEqual(check.words(for: space), "⌘Space is Spotlight's key.")
        XCTAssertEqual(check.words(for: free), "⌥Space is free.")
    }
}
