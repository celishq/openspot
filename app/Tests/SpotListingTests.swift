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

    private func spot(_ header: String, body: String = "", named name: String = "timer") throws -> Spot {
        let url = folder.spotFile(name)
        try "#!/bin/sh\n\(header)\n\(body)\n".writeScript(to: url)
        return try XCTUnwrap(try SpotFile(file: url, id: name)?.spots.first)
    }

    func testTheListingReadsTheReadmeAndThePreviewBesideTheSpot() throws {
        let spot = try self.spot("# title=Timer\n# detail=Counts down")
        try "Counts down from a time you pick.".write(to: folder.appendingPathComponent("timer.spot/readme.md"), atomically: true, encoding: .utf8)
        try "row=five\ntitle=5 minutes\n\nrow=ten\ntitle=10 minutes\n".write(to: folder.appendingPathComponent("timer.spot/preview.txt"), atomically: true, encoding: .utf8)

        let listing = SpotListing(beside: spot)

        XCTAssertEqual(listing.description, "Counts down")
        XCTAssertEqual(listing.readme, "Counts down from a time you pick.")
        XCTAssertEqual(listing.preview.map(\.title), ["5 minutes", "10 minutes"])
    }

    func testASpotWithNoFilesBesideItHasOnlyItsDescription() throws {
        let listing = SpotListing(beside: try spot("# detail=Counts down"))

        XCTAssertEqual(listing.description, "Counts down")
        XCTAssertNil(listing.readme)
        XCTAssertEqual(listing.preview, [])
    }

    func testPreviewSampleMarksASpotThatPrintsFakeData() throws {
        XCTAssertTrue(try spot("# preview=sample", named: "sample").previewsSample)
        XCTAssertFalse(try spot("# title=Timer", named: "plain").previewsSample)
        let live = folder.spotFile("live")
        try "#!/bin/sh\n# preview=live\n".writeScript(to: live)
        XCTAssertThrowsError(try SpotFile(file: live, id: "live"))
    }

    @MainActor
    func testTheCaptureRunsThePreviewModeAsTheSpotsCallAndKeepsItsTextBesideTheSpot() async throws {
        let spot = try self.spot("# preview=sample", body: "[ \"$OPENSPOT_REASON\" = spot.preview ] && [ -n \"$OPENSPOT_TOKEN\" ] && printf 'row=a\\ntitle=Sample\\n' || printf 'row=a\\ntitle=Real\\n'")
        let runs = SpotRuns()
        defer { runs.quit() }

        try await SpotListing.capturePreview(of: spot, runs: runs)

        XCTAssertEqual(SpotListing(beside: spot).preview.map(\.title), ["Sample"])
    }

    func testEachCoreSpotHasAReadme() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../plugins").standardizedFileURL
        let choices = SpotFolder(url: folder, core: plugins).coreChoices()

        XCTAssertFalse(choices.isEmpty)
        for spot in choices {
            XCTAssertNotNil(SpotListing(beside: spot).readme, "\(spot.name) has no readme")
        }
    }
}
