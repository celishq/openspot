import XCTest
@testable import OpenspotCore

final class SpotEventTests: XCTestCase {
    func testTheEventsTableOfTheReferenceListsEachSpotEventOnce() throws {
        let text = try RepoDoc("docs/reference/spot-toml.md").text
        let table = text.components(separatedBy: "## Events\n").dropFirst().first?.components(separatedBy: "\n\n").first ?? ""
        let listed = table.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("| `") else { return nil }
            return line.dropFirst(3).prefix { $0 != "`" }.description
        }

        XCTAssertEqual(listed, SpotEvent.all.map(\.name))
    }

    func testAnEventThatTakesNoValueIsMarkedSo() {
        XCTAssertEqual(SpotEvent.named(EventName.calendarChange)?.takesValue, false)
        XCTAssertEqual(SpotEvent.named(EventName.powerChange)?.takesValue, true)
        XCTAssertNil(SpotEvent.named("sheet.close"))
    }
}
