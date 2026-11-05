import XCTest
@testable import OpenspotCore

final class FileIconTests: XCTestCase {
    func testFilesOfOneTypeShareOneIcon() {
        XCTAssertEqual(FileIcon(path: "/a/report.PDF"), FileIcon(path: "/b/notes.pdf"))
        XCTAssertEqual(FileIcon(path: "/a/report.pdf"), .type("pdf"))
    }

    func testAnAppHasItsOwnIcon() {
        XCTAssertEqual(FileIcon(path: "/Applications/Safari.app"), .file("/Applications/Safari.app"))
    }

    func testAPathWithNoExtensionHasItsOwnIcon() {
        XCTAssertEqual(FileIcon(path: "/Users/me/Downloads"), .file("/Users/me/Downloads"))
    }

    func testAnItemUsesItsImageBeforeItsFile() {
        let item = SpotItem(title: "A", run: "a", file: "/a/report.pdf", image: "/icons/a.icon")

        XCTAssertEqual(item.icon, .image("/icons/a.icon"))
    }

    func testAnItemWithAFileUsesTheIconOfTheFile() {
        XCTAssertEqual(SpotItem(title: "A", run: "a", file: "/a/report.pdf").icon, .type("pdf"))
    }

    func testAnItemWithNeitherHasNoIcon() {
        XCTAssertNil(SpotItem(title: "A", run: "a").icon)
    }
}
