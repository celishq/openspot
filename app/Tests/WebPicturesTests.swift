import XCTest
@testable import OpenspotCore

final class WebPicturesTests: XCTestCase {
    private final class Fetches: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []

        func add(_ url: URL) {
            lock.withLock { urls.append(url) }
        }

        var count: Int {
            lock.withLock { urls.count }
        }
    }

    private struct Failure: Error {}

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-pictures-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testAPictureOnTheWebIsFetchedOnceAndKept() async throws {
        let fetches = Fetches()
        let pictures = WebPictures(folder: folder) { url in
            fetches.add(url)
            return Data("png".utf8)
        }

        let fetched = await pictures.path(of: "https://example.com/a.png?s=64")
        let second = await pictures.path(of: "https://example.com/a.png?s=64")
        let first = try XCTUnwrap(fetched)

        XCTAssertEqual(second, first)
        XCTAssertEqual(fetches.count, 1)
        XCTAssertTrue(first.hasPrefix(folder.path))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: first)), Data("png".utf8))
    }

    func testTheKeptPicturesStayUnderTheirLimitAndTheNewestStays() async throws {
        let pictures = WebPictures(folder: folder, limit: 10) { _ in Data("123456".utf8) }

        for name in ["a", "b", "c"] { _ = await pictures.path(of: "https://example.com/\(name).png") }
        let newest = await pictures.path(of: "https://example.com/c.png")

        let sizes = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])
            .map { try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 }
        XCTAssertLessThanOrEqual(sizes.reduce(0, +), 10)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(newest)))
    }

    func testAnOutputNamesItsPicturesOnTheWebForARenderToFetch() {
        let output = SpotOutput(text: "row=a\nicon=https://example.com/a.png\n\nchoice=c\n\noption=x\nicon=https://example.com/x.png\n\nrow=b\nicon=wifi\n")

        XCTAssertEqual(output.webPictures, ["https://example.com/a.png", "https://example.com/x.png"])
    }

    func testAPathStaysAndAFailedOrTooLargeFetchKeepsNothing() async throws {
        let failing = WebPictures(folder: folder) { _ in throw Failure() }
        let large = WebPictures(folder: folder) { _ in Data(count: WebPictures.byteLimit + 1) }

        let path = await failing.path(of: "/tmp/a.png")
        let failed = await failing.path(of: "https://example.com/a.png")
        let tooLarge = await large.path(of: "https://example.com/b.png")

        XCTAssertEqual(path, "/tmp/a.png")
        XCTAssertNil(failed)
        XCTAssertNil(tooLarge)
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [], [])
    }
}
