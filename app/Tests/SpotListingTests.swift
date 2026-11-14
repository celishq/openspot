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

        let preview = try String(contentsOf: SpotListing.preview(of: spot.url), encoding: .utf8)
        XCTAssertEqual(SpotOutput(text: preview).items.map(\.title), ["Sample"])
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
