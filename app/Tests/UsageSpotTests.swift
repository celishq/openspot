import XCTest
@testable import OpenspotCore

final class UsageSpotTests: SampleSpotsCase {
    func testOpenOnThePageOfASpotOpensThatSpot() async throws {
        let usage = try XCTUnwrap(try scan.spots.first { $0.name == "Usage" })
        try await withPrivateHome { folder in
            let page = try await Self.answer(of: usage, ["show"], input: "input.route=spot:links\n")
            try await usage.perform(SpotWords(arguments: ["press"]), page: "spot:links", timeout: 30)
            let pressed = try? self.read("opened-spots", in: folder)
            try await usage.perform(SpotWords(arguments: ["open-spot"]), page: "spot:links", timeout: 30)

            XCTAssertEqual(page.actions.first { $0.id == "open-spot" }?.title, "Open")
            XCTAssertNil(pressed)
            XCTAssertEqual(try self.read("opened-spots", in: folder), "links\n")
        }
    }
}
