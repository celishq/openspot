import XCTest
@testable import OpenspotCore

final class KeyLayoutTests: XCTestCase {
    private let latin = KeyLayout(keys: [0: "a", 1: "s", 3: "f", 15: "r", 34: "i", 43: ","])
    private let cyrillic = KeyLayout(keys: [0: "ф", 1: "ы", 3: "а", 15: "к", 34: "ш", 43: "б"])

    private func titles(_ text: String, in titles: [String]) -> [String] {
        SearchQuery(text: text, layouts: [latin, cyrillic]).matching(titles.map { SpotItem(title: $0, run: $0) }).map(\.title)
    }

    func testATextTypedInAnotherLayoutFindsItsTitle() {
        XCTAssertEqual(titles("ыфафкш", in: ["Notes", "Safari"]), ["Safari"])
    }

    func testALatinTextFindsATitleOfTheOtherLayout() {
        XCTAssertEqual(titles("f,", in: ["Notes", "аб"]), ["аб"])
    }

    func testACapitalTypedInAnotherLayoutFindsItsTitle() {
        XCTAssertEqual(titles("ЫФА", in: ["Safari"]), ["Safari"])
    }

    func testATextWithAKeyThatTheLayoutsLackGetsOnlyItsLatinSpelling() {
        XCTAssertEqual(SearchQuery(text: "ы1", layouts: [latin, cyrillic]).forms, ["y1"])
    }

    func testTheFormsHoldTheTextOfEachOtherLayout() {
        XCTAssertEqual(SearchQuery(text: "ыфа", layouts: [latin, cyrillic]).forms, ["saf", "yfa"])
    }

    func testOneLayoutGivesNoForms() {
        XCTAssertEqual(SearchQuery(text: "saf", layouts: [latin]).forms, [])
    }
}
