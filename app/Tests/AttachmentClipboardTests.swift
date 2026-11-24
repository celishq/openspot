import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentClipboardTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")
    private let board = FakeClipboard()

    override func setUp() async throws {
        try await super.setUp()
        model.runs.api = CommandAPI(mac: Mac(clipboard: board), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    private func openCopy() async throws {
        try source("copy", adds: "clipboard")
        await open()
        try await wait("the end of the source") { self.log("done").count == 1 }
    }

    private func give() async throws {
        try await wait("the value of the copy") { self.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(tab))
        model.runSelected()
    }

    func testALongCopyIsHeldInPartAndHandedOnWhole() async throws {
        let long = String(repeating: "a", count: ClipboardCopy.heldLength * 2)
        board.copy(long)
        try taker(takes: "'text'")

        try await openCopy()
        try await wait("the value of the copy") { self.chips.first?.value != nil }
        let held = try XCTUnwrap(chips.first?.value?.texts.first)
        try await give()

        try await wait("the hand-off") { self.log("keep-drops").count == 2 }
        XCTAssertEqual(held.count, ClipboardCopy.heldLength)
        XCTAssertEqual(log("keep-drops").first?.count, "input.text=".count + long.count)
        XCTAssertEqual(log("keep-drops").last, "input.title=Copied text")
    }

    func testAShortCopyIsHeldWholeAndALinkAsALink() async throws {
        board.copy("https://example.com/a")
        try taker(takes: "'url'")

        try await openCopy()

        try await wait("the value of the copy") { self.chips.first?.value != nil }
        XCTAssertEqual(chips.first?.value, AttachmentValue(url: "https://example.com/a"))
    }

    func testCopiedFilesGiveAFileChip() async throws {
        let movie = path("a.mov")
        FileManager.default.createFile(atPath: movie, contents: Data())
        board.copy(files: [URL(fileURLWithPath: movie)])
        try taker(takes: "'mov'")

        try await openCopy()
        try await give()

        try await wait("the drop") { self.log("keep-drops").count == 1 }
        XCTAssertEqual(log("keep-drops"), ["input.file=\(movie)"])
    }

    func testACopiedImageIsWrittenToAFileOnlyWhenItIsHandedOn() async throws {
        board.copy(image: Data("png bytes".utf8), kind: "png")
        try taker(takes: "'png'")

        try await openCopy()
        try await wait("the value of the copy") { self.chips.first?.value != nil }
        let file = try XCTUnwrap(chips.first?.value?.texts.first)
        let writtenAtOpen = FileManager.default.fileExists(atPath: file)
        try await give()

        try await wait("the drop") { self.log("keep-drops").count == 1 }
        XCTAssertFalse(writtenAtOpen)
        XCTAssertEqual(log("keep-drops"), ["input.file=\(file)"])
        XCTAssertEqual(FileManager.default.contents(atPath: file), Data("png bytes".utf8))
    }

    func testAConcealedCopyGivesNoChip() async throws {
        board.copy(concealed: "secret")
        try taker(takes: "'text'")

        try await openCopy()

        XCTAssertEqual(chips, [])
    }

    func testALongCopyThatChangedBeforeTheHandOffIsNotHandedOnAndSaysSo() async throws {
        board.copy(String(repeating: "a", count: ClipboardCopy.heldLength + 1))
        try taker(takes: "'text'")

        try await openCopy()
        board.copy("newer")
        try await give()

        try await wait("the note") { self.host.confirms.contains(ClipboardCopy.changed) }
        XCTAssertEqual(log("keep-drops"), [])
    }
}
