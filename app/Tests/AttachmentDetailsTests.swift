import ImageIO
import XCTest
@testable import OpenspotCore

final class AttachmentDetailsTests: XCTestCase {
    private func node(_ id: String, of details: AttachmentDetails?) -> ViewNode? {
        details?.tree.node(id)
    }

    func testAReadOfNoKnownAppSaysReading() {
        let chip = AttachmentChip(source: "tab", app: nil, look: .symbol("globe"), state: .loading)

        XCTAssertEqual(node("caption", of: AttachmentDetails(state: chip))?.title, "Reading…")
    }

    func testALinkShowsItsTitleUnderItsHost() {
        let details = AttachmentDetails(AttachmentValue(url: "https://developer.apple.com/documentation/swiftui", title: "SwiftUI"))

        XCTAssertEqual(node("words", of: details)?.title, "SwiftUI")
        XCTAssertEqual(node("caption", of: details)?.title, "developer.apple.com")
        XCTAssertEqual(node("caption", of: details)?.icon, .symbol("arrow.up.right"))
        XCTAssertEqual(details.label, "SwiftUI")
    }

    func testATextShowsItsWordsOnOneRunOfLines() {
        let details = AttachmentDetails(AttachmentValue(text: "  one\n\ntwo   three ", title: "Selected text"))

        XCTAssertEqual(node("words", of: details)?.title, "one two three")
        XCTAssertEqual(node("caption", of: details)?.title, "Selected text")
        XCTAssertEqual(node("caption", of: details)?.icon, .symbol("textformat"))
    }

    func testFilesShowTheirNamesAndTheirFolder() {
        let details = AttachmentDetails(AttachmentValue(files: FileKinds(["/a/docs/one.md", "/a/docs/two.md"])))

        XCTAssertEqual(node("words", of: details)?.title, "one.md, two.md")
        XCTAssertEqual(node("caption", of: details)?.title, "2 files in docs")
    }

    func testAFileShowsItselfAsAPictureAndAudioAWaveform() {
        func picture(_ path: String) -> Icon? {
            node("picture", of: AttachmentDetails(AttachmentValue(files: FileKinds([path]))))?.icon
        }

        XCTAssertEqual(picture("/a/shot.PNG"), .image("/a/shot.PNG"))
        XCTAssertEqual(picture("/a/talk.mov"), .image("/a/talk.mov"))
        XCTAssertEqual(picture("/a/notes.md"), .file("/a/notes.md"))
        XCTAssertEqual(picture("/a/song.mp3"), .symbol("waveform"))
        XCTAssertNil(node("picture", of: AttachmentDetails(AttachmentValue(text: "words"))))
    }

    func testAPictureKeepsTheHeightOfAPreviewWithoutOne() {
        let picture = AttachmentDetails(AttachmentValue(files: FileKinds(["/a/shot.png"])))
        let words = AttachmentDetails(AttachmentValue(text: "shot.png"))

        XCTAssertEqual(picture.lines, words.lines)
    }

    func testWordsBesideAPictureWrapSooner() {
        let name = String(repeating: "n", count: Int(SpotTokens.detailsWidth / (CGFloat(SpotTokens.layout.type.body) * SpotTokens.glyphWidthShare))) + ".png"

        XCTAssertEqual(SpotTokens.detailsLines(of: name), 2)
        XCTAssertEqual(SpotTokens.detailsLines(of: String(name.dropLast(6))), 1)
        XCTAssertEqual(SpotTokens.detailsLines(of: String(name.dropLast(6)), besidePicture: true), 2)
    }

    func testAClassWithTheDetailsPrefixAppliesInTheDetailsAndOneForStripCardsDoesNot() throws {
        let blocks = TextBlock.blocks(in: "frame=\nclass=flex-col\n\ntext=a\ntitle=A\nclass=details:hidden\n\ntext=b\ntitle=B\nclass=strip:hidden\n")
        let details = AttachmentDetails(AttachmentValue(.url("https://example.com"), details: blocks))

        XCTAssertEqual(details.tree.node("a")?.style.resolved(for: AttachmentDetails.variants).isHidden, true)
        XCTAssertNotEqual(details.tree.node("b")?.style.resolved(for: AttachmentDetails.variants).isHidden, true)
    }

    func testACopiedImageShowsASmallThumbnailSavedOnceFromItsBytes() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let board = FakeClipboard()
        board.copy(image: try Self.png(width: 1200, height: 600), kind: "png")
        let value = try XCTUnwrap(Clipboard(board: board).value(count: board.count(), images: folder))

        guard case .image(let path)? = node("picture", of: AttachmentDetails(value))?.icon else { return XCTFail("no thumbnail") }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(max(image.width, image.height), Clipboard.thumbnailPixels)
        XCTAssertLessThan(data.count, 200_000)
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
