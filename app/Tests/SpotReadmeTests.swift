import XCTest
@testable import OpenspotCore

final class SpotReadmeTests: XCTestCase {
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
            XCTAssertTrue(FileManager.default.fileExists(atPath: SpotReadme.url(beside: spot.url).path), "\(spot.name) has no readme")
        }
    }

    func testALineThatHoldsOnlyAMarkdownImageIsAPictureOrAVideo() {
        XCTAssertEqual(SpotReadme.media(in: "![The sheet](shot.png)")?.source, "shot.png")
        XCTAssertEqual(SpotReadme.media(in: "![The sheet](shot.png)")?.caption, "The sheet")
        XCTAssertEqual(SpotReadme.media(in: "![](demo.mov)")?.caption, "")
        XCTAssertNil(SpotReadme.media(in: "See ![x](a.png) here"))
        XCTAssertNil(SpotReadme.media(in: "![x](a.png) and more"))
    }

    func testTheLinesNameEachPictureOrVideoInTheFolderByItsFullPath() throws {
        let readme = folder.appendingPathComponent("timer.spot/readme.md")
        try FileManager.default.createDirectory(at: readme.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Timer\n\n![The sheet](shot.png)\n![](/tmp/a.mov)\n![Web](https://example.com/a.jpg)\n".write(to: readme, atomically: true, encoding: .utf8)
        let folder = readme.deletingLastPathComponent().path

        XCTAssertEqual(SpotReadme.lines(at: readme), ["# Timer", "", "![The sheet](\(folder)/shot.png)", "![](/tmp/a.mov)", "![Web](https://example.com/a.jpg)"])
    }

    func testTheReviewShowsAPictureOrVideoByItsCaptionOrItsFileName() {
        XCTAssertEqual(SpotReadme.shown("# Timer\n![The sheet](shot.png)\n![](demo.mov)\nCounts down."), "# Timer\n[The sheet]\n[demo.mov]\nCounts down.")
    }
}
