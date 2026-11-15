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

    func testASampleScriptBesideASpotGivesItASampleAndIsNoSpotOfItsOwn() throws {
        let timer = try spot("# title=Timer")
        let sample = SpotListing.sampleScript(of: timer.url)
        try "#!/bin/sh\nprintf 'row=a\\ntitle=Sample\\n'\n".writeScript(to: sample)

        XCTAssertEqual(try spot("# title=Timer").sample, sample)
        XCTAssertNil(try spot("# title=Plain", named: "plain").sample)
        XCTAssertNil(try SpotFile(file: sample, id: "timer/sample"))
    }

    func testAScriptNamedSampleInItsOwnFolderIsASpot() throws {
        let spot = try self.spot("# title=Sample", named: "sample")

        XCTAssertEqual(spot.name, "Sample")
        XCTAssertNil(spot.sample)
    }

    func testAnOldPreviewKeyStillLoadsTheSpot() throws {
        XCTAssertNil(try spot("# preview=sample").sample)
    }

    @MainActor
    func testTheCaptureRunsTheSampleScriptAndKeepsItsTextBesideTheSpot() async throws {
        try "#!/bin/sh\nprintf 'row=a\\ntitle=Sample\\n'\n".writeScript(to: SpotListing.sampleScript(of: folder.spotFile("timer")))
        let spot = try self.spot("# title=Timer", body: "printf 'row=a\\ntitle=Real\\n'")
        let runs = SpotRuns()
        defer { runs.quit() }

        try await SpotListing.captureSample(of: spot, runs: runs)

        let sample = try String(contentsOf: SpotListing.sampleText(of: spot.url), encoding: .utf8)
        XCTAssertEqual(SpotOutput(text: sample).items.map(\.title), ["Sample"])
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
