import XCTest
@testable import OpenspotCore

final class SpotListingTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-listing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testEachCoreSpotHasAReadme() throws {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../spots").standardizedFileURL
        let choices = SpotsFolder(url: folder, core: spots).coreChoices()

        XCTAssertFalse(choices.isEmpty)
        for spot in choices {
            XCTAssertTrue(FileManager.default.fileExists(atPath: SpotListing.readme(of: spot.url).path), "\(spot.name) has no readme")
        }
    }
}
