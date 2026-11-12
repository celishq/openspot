import XCTest
@testable import OpenspotCore

/// Proves when the System details spot reads.
final class SystemInfoSpotTests: SampleSpotsCase {
    private func systemInfo() throws -> Spot {
        try XCTUnwrap(try scan.spots.first { $0.name == "System details" })
    }

    func testSystemDetailsReadsOnlyWhenItsSheetOpens() throws {
        let read = try XCTUnwrap(try systemInfo().read)

        XCTAssertTrue(read.has(.sheet))
        XCTAssertFalse(read.has(.panel))
    }
}
