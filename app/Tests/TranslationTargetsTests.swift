import XCTest
@testable import OpenspotCore

final class TranslationTargetsTests: XCTestCase {
    func testKeepsEachPreferredLanguageOnceWithNoCountryAndWithoutTheSource() {
        XCTAssertEqual(TranslationTargets(preferred: ["en-UA", "en", "ru", "uk_UA"], source: "ru").codes, ["en", "uk"])
    }

    func testTextInTheOnlyLanguageHasNoTarget() {
        XCTAssertEqual(TranslationTargets(preferred: ["en"], source: "en").codes, [])
    }
}
