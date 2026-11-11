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
        let url = folder.appendingPathComponent("\(name).sh")
        try "#!/bin/sh\n\(header)\n\(body)\n".writeScript(to: url)
        return try XCTUnwrap(try Plugin(file: url, id: name)?.commands.first)
    }

    func testTheListingReadsTheReadmeAndThePreviewBesideTheSpot() throws {
        let command = try spot("# title=Timer\n# detail=Counts down")
        try "Counts down from a time you pick.".write(to: folder.appendingPathComponent("timer.md"), atomically: true, encoding: .utf8)
        try "row=five\ntitle=5 minutes\n\nrow=ten\ntitle=10 minutes\n".write(to: folder.appendingPathComponent("timer.preview.txt"), atomically: true, encoding: .utf8)

        let listing = SpotListing(beside: command)

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
        let live = folder.appendingPathComponent("live.sh")
        try "#!/bin/sh\n# preview=live\n".writeScript(to: live)
        XCTAssertThrowsError(try Plugin(file: live, id: "live"))
    }

    func testTheCaptureRunsThePreviewModeAndKeepsItsTextBesideTheSpot() async throws {
        let command = try spot("# preview=sample", body: "[ \"$OPENSPOT_PREVIEW\" = 1 ] && printf 'row=a\\ntitle=Sample\\n' || printf 'row=a\\ntitle=Real\\n'")

        try await SpotListing.capturePreview(of: command)

        XCTAssertEqual(SpotListing(beside: command).preview.map(\.title), ["Sample"])
    }

    func testEachCoreSpotHasAReadme() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../plugins").standardizedFileURL
        let choices = PluginFolder(url: folder, core: plugins).coreChoices()

        XCTAssertFalse(choices.isEmpty)
        for command in choices {
            XCTAssertNotNil(SpotListing(beside: command).readme, "\(command.name) has no readme")
        }
    }
}
