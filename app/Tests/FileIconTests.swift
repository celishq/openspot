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
}
