import XCTest
@testable import OpenspotCore

final class ContextPreviewTests: XCTestCase {
    func testALinkShowsItsTitleAndItsHost() {
        let preview = ContextPreview(ContextValue(url: "https://developer.apple.com/documentation/swiftui", title: "SwiftUI"))

        XCTAssertEqual(preview.text, "SwiftUI")
        XCTAssertEqual(preview.caption, "developer.apple.com")
        XCTAssertEqual(preview.symbol, "arrow.up.right")
    }

    func testATextShowsItsWordsOnOneRunOfLines() {
        let preview = ContextPreview(ContextValue(text: "  one\n\ntwo   three ", title: "Selected text"))

        XCTAssertEqual(preview.text, "one two three")
        XCTAssertEqual(preview.caption, "Selected text")
        XCTAssertEqual(preview.symbol, "textformat")
    }

    func testFilesShowTheirNamesAndTheirFolder() {
        let files = FileKinds(["/a/docs/one.md", "/a/docs/two.md"])
        let preview = ContextPreview(ContextValue(files: files))

        XCTAssertEqual(preview.text, "one.md, two.md")
        XCTAssertEqual(preview.caption, "2 files in docs")
        XCTAssertEqual(preview.symbol, "doc")
    }
}
