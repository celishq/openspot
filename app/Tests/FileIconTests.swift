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

    func testAnExtensionHasItsOwnIcon() {
        let pane = "/System/Library/ExtensionKit/Extensions/Wi-Fi.appex"

        XCTAssertEqual(FileIcon(path: pane), .file(pane))
    }

    func testAPathWithNoExtensionHasItsOwnIcon() {
        XCTAssertEqual(FileIcon(path: "/Users/me/Downloads"), .file("/Users/me/Downloads"))
    }

    func testAnItemWithAnImageUsesTheImage() {
        XCTAssertEqual(SpotItem(title: "A", run: "a", picture: .image("/icons/a.icon")).icon, .image("/icons/a.icon"))
    }

    func testAnItemWithAFileUsesTheIconOfTheFile() {
        XCTAssertEqual(SpotItem(title: "A", run: "a", picture: .file("/a/report.pdf")).icon, .type("pdf"))
    }

    func testAnItemWithNeitherHasNoIcon() {
        XCTAssertNil(SpotItem(title: "A", run: "a").icon)
    }
}
