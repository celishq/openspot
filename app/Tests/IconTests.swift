import XCTest
@testable import OpenspotCore

final class IconTests: XCTestCase {
    func testTheValueSaysWhatThePictureIs() {
        XCTAssertEqual(Icon(text: "wifi"), .symbol("wifi"))
        XCTAssertEqual(Icon(text: "arrow.up.circle.fill"), .symbol("arrow.up.circle.fill"))
        XCTAssertEqual(Icon(text: "/Applications/Safari.app"), .file("/Applications/Safari.app"))
        XCTAssertEqual(Icon(text: "~/Notes"), .file("~/Notes"))
        XCTAssertEqual(Icon(text: "/tmp/photo.JPG"), .image("/tmp/photo.JPG"))
        XCTAssertEqual(Icon(text: "cups.png"), .image("cups.png"))
        XCTAssertEqual(Icon(text: "https://avatars.example.com/u/1?s=64"), .image("https://avatars.example.com/u/1?s=64"))
        XCTAssertEqual(Icon(text: "😀"), .glyph("😀"))
        XCTAssertEqual(Icon(text: "→"), .glyph("→"))
        XCTAssertEqual(Icon(text: "A"), .glyph("A"))
        XCTAssertNil(Icon(text: ""))
        XCTAssertNil(Icon(text: nil))
    }

    func testARowAndAComponentTakeTheirPictureFromIcon() throws {
        let output = PluginOutput(text: "grid=p\ngrid=rows\n\npicture=p\nicon=/tmp/a.png\n\nrow=a\nicon=/Applications/Safari.app\n\nrow=b\nicon=😀\n")

        XCTAssertEqual(output.items.map(\.iconFile), ["/Applications/Safari.app", nil])
        XCTAssertEqual(output.items.map(\.glyph), [nil, "😀"])
        XCTAssertEqual(output.parts.first?.control, .image("/tmp/a.png"))
        XCTAssertEqual(output.partFaults, [])
    }
}
