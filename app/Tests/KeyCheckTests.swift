import XCTest
@testable import OpenspotCore

final class KeyCheckTests: XCTestCase {
    func testAFreeKeyAndKeysThatDoSomething() throws {
        let space = try XCTUnwrap(Shortcut(code: 49, modifiers: .command))
        let input = try XCTUnwrap(Shortcut(code: 49, modifiers: .control))
        let free = try XCTUnwrap(Shortcut(code: 49, modifiers: .option))
        let check = KeyCheck(taken: [TakenKey(shortcut: space, use: "opens Spotlight"), TakenKey(shortcut: input, use: "switches to the previous input source")])
        XCTAssertEqual(check.words(for: space), "⌘Space opens Spotlight.")
        XCTAssertEqual(check.words(for: input), "⌃Space switches to the previous input source.")
        XCTAssertEqual(check.words(for: free), "⌥Space is free.")
    }
}
