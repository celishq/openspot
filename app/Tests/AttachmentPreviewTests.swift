import ImageIO
import XCTest
@testable import OpenspotCore

final class AttachmentPreviewTests: XCTestCase {
    func testAReadOfNoKnownAppSaysReading() {
        let chip = AttachmentChip(source: "tab", app: nil, look: .symbol("globe"), state: .loading)

        XCTAssertEqual(AttachmentPreview(state: chip)?.caption, "Reading…")
    }

    func testALinkShowsItsTitleAndItsHost() {
        let preview = AttachmentPreview(AttachmentValue(url: "https://developer.apple.com/documentation/swiftui", title: "SwiftUI"))

        XCTAssertEqual(preview.text, "SwiftUI")
        XCTAssertEqual(preview.caption, "developer.apple.com")
        XCTAssertEqual(preview.symbol, "arrow.up.right")
    }

    func testATextShowsItsWordsOnOneRunOfLines() {
        let preview = AttachmentPreview(AttachmentValue(text: "  one\n\ntwo   three ", title: "Selected text"))

        XCTAssertEqual(preview.text, "one two three")
        XCTAssertEqual(preview.caption, "Selected text")
        XCTAssertEqual(preview.symbol, "textformat")
    }

    func testFilesShowTheirNamesAndTheirFolder() {
        let files = FileKinds(["/a/docs/one.md", "/a/docs/two.md"])
        let preview = AttachmentPreview(AttachmentValue(files: files))

        XCTAssertEqual(preview.text, "one.md, two.md")
        XCTAssertEqual(preview.caption, "2 files in docs")
        XCTAssertEqual(preview.symbol, "doc")
    }

    func testAPictureOrAVideoShowsItsThumbnailAudioAWaveformAndEveryOtherFileItsIcon() {
        func picture(_ path: String) -> AttachmentPreview.Picture? {
            AttachmentPreview(AttachmentValue(files: FileKinds([path]))).picture
        }

        XCTAssertEqual(picture("/a/shot.PNG"), .thumbnail("/a/shot.PNG"))
        XCTAssertEqual(picture("/a/cat.gif"), .thumbnail("/a/cat.gif"))
        XCTAssertEqual(picture("/a/talk.mov"), .thumbnail("/a/talk.mov"))
        XCTAssertEqual(picture("/a/deck.pdf"), .thumbnail("/a/deck.pdf"))
        XCTAssertEqual(picture("/a/song.mp3"), .symbol("waveform"))
        XCTAssertEqual(picture("/a/notes.md"), .icon("/a/notes.md"))
        XCTAssertEqual(picture("/a/docs"), .icon("/a/docs"))
        XCTAssertNil(AttachmentPreview(AttachmentValue(text: "words")).picture)
    }

    func testAPictureKeepsTheHeightOfAPreviewWithoutOne() {
        let picture = AttachmentPreview(AttachmentValue(files: FileKinds(["/a/shot.png"])))
        let words = AttachmentPreview(AttachmentValue(text: "shot.png"))

        XCTAssertEqual(picture.lines, words.lines)
        XCTAssertEqual(SpotTokens.attachmentValueRoom(lines: picture.lines), SpotTokens.attachmentValueRoom(lines: words.lines))
        XCTAssertLessThanOrEqual(SpotTokens.attachmentPicture, SpotTokens.attachmentValueRoom(lines: 1) - SpotTokens.attachmentValuePadding - SpotTokens.attachmentValueFoot)
    }

    func testWordsBesideAPictureWrapSooner() {
        let name = String(repeating: "n", count: Int(SpotTokens.attachmentValueWidth / (CGFloat(SpotTokens.layout.type.body) * SpotTokens.glyphWidthShare))) + ".png"

        XCTAssertEqual(SpotTokens.attachmentValueLines(of: name), 2)
        XCTAssertEqual(SpotTokens.attachmentValueLines(of: String(name.dropLast(6))), 1)
        XCTAssertEqual(SpotTokens.attachmentValueLines(of: String(name.dropLast(6)), besidePicture: true), 2)
    }

    func testACopiedImageShowsASmallThumbnailMadeOnceFromItsBytes() throws {
        let board = FakeClipboard()
        board.copy(image: try Self.png(width: 1200, height: 600), kind: "png")
        let value = try XCTUnwrap(Clipboard(board: board).value(count: board.count(), images: URL(fileURLWithPath: "/tmp/none")))

        guard case .data(let thumbnail)? = AttachmentPreview(value).picture else { return XCTFail("no thumbnail") }
        let source = try XCTUnwrap(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(max(image.width, image.height), Clipboard.thumbnailPixels)
        XCTAssertLessThan(thumbnail.count, 200_000)
    }

    private static func png(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
