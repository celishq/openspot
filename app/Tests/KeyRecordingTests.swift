import XCTest
@testable import OpenspotCore

@MainActor
final class KeyRecordingTests: XCTestCase {
    func testAFreeKeyAndKeysThatDoSomething() throws {
        let space = try XCTUnwrap(Shortcut(code: 49, modifiers: .command))
        let input = try XCTUnwrap(Shortcut(code: 49, modifiers: .control))
        let free = try XCTUnwrap(Shortcut(code: 49, modifiers: .option))
        let keys = KeyRecording()
        keys.take([TakenKey(shortcut: space, use: "opens Spotlight"), TakenKey(shortcut: input, use: "switches to the previous input source")])
        XCTAssertEqual(keys.words(for: space), "⌘Space opens Spotlight.")
        XCTAssertEqual(keys.words(for: input), "⌃Space switches to the previous input source.")
        XCTAssertEqual(keys.words(for: free), "⌥Space is free.")
    }

    func testAStartClearsTheWordsAndTheHeldKeys() {
        let keys = KeyRecording(status: "old")
        _ = keys.hold(.option)

        keys.start()

        XCTAssertNil(keys.status)
        XCTAssertEqual(keys.held, [])
    }
}
