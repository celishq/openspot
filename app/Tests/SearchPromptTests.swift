import XCTest
@testable import OpenspotCore

final class SearchPromptTests: XCTestCase {
    func testATitleTakesTheCaseOfARunningSentence() {
        XCTAssertEqual(SearchPrompt.word(for: "Apps"), "apps")
        XCTAssertEqual(SearchPrompt.word(for: "Pull requests"), "pull requests")
    }

    func testAWordWithItsOwnCapitalsKeepsThem() {
        XCTAssertEqual(SearchPrompt.word(for: "GitHub pulls"), "GitHub pulls")
        XCTAssertEqual(SearchPrompt.word(for: "iCloud"), "iCloud")
        XCTAssertEqual(SearchPrompt.word(for: "CPU"), "CPU")
    }
}
