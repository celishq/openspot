import XCTest
@testable import OpenspotCore

@MainActor
final class SourceSpotTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")
    private let reads = FakeReads()
    private let board = FakeClipboard()

    override func setUp() async throws {
        try await super.setUp()
        var environment = TestEnvironment.values
        environment["PATH"] = client.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        model.quit()
        model = SpotsModel(host: host, files: model.files, runs: SpotRuns(environment: environment, stopPause: stopPause))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(clipboard: board, reads: ReadSources(mac: reads)), places: model.files, app: ModelApp(model: model), runs: model.runs)
        model.runs.listen(to: board)
        try taker(takes: "'url', 'text', '*'")
    }

    private func copy(_ name: String) throws {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots/\(name).spot")
        try FileManager.default.copyItem(at: source, to: spots.appendingPathComponent("\(name).spot"))
    }

    private func state(of id: String) -> AttachmentChip.State? {
        chips.first { $0.source == id }?.state
    }

    func testBrowserTabReadsTheFrontTabOfTheAppInFrontWhenTabPicksIt() async throws {
        try copy("browser-tab")
        reads.set(answers: ["com.apple.Safari": ["https://a.com/", "A page"]])
        await open()
        XCTAssertEqual(state(of: "browser-tab"), .unread)

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the tab") { self.chips.first?.value != nil }
        XCTAssertEqual(state(of: "browser-tab"), .ready(AttachmentValue(url: "https://a.com/", title: "A page", app: "com.apple.Safari")))
    }

    func testBrowserTabOffersAllowWhenTheReadIsRefused() async throws {
        try copy("browser-tab")
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .unasked])
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the refusal") { self.state(of: "browser-tab") == .failed("Openspot can't read Safari · ⏎ Allow") }
        XCTAssertEqual(host.notes, [])
    }

    func testSelectionAddsTheFilesSelectedInFinderWhenThePanelOpens() async throws {
        try copy("selection")
        let file = path("a.txt")
        FileManager.default.createFile(atPath: file, contents: Data())
        host.frontApp = FrontApp(bundleID: "com.apple.finder")
        reads.set(front: "com.apple.finder", answers: ["com.apple.finder": [file]])

        await open()

        try await wait("the files") { self.state(of: "selection") != nil }
        XCTAssertEqual(chips.first?.value?.values, [file])
        XCTAssertEqual(chips.first?.value?.app, "com.apple.finder")
        XCTAssertNil(chips.first?.value?.title)
    }

    func testSelectionAddsTheSelectedTextWhenThePanelOpens() async throws {
        try copy("selection")
        reads.set(front: "com.apple.Safari", selected: "two words")

        await open()

        try await wait("the selection") { self.state(of: "selection") != nil }
        XCTAssertEqual(state(of: "selection"), .ready(AttachmentValue(text: "two words", title: "Selected text", app: "com.apple.Safari")))
    }

    func testSelectionAddsNothingWhenNothingIsSelectedInFinder() async throws {
        try await addsNothing(over: "com.apple.finder")
    }

    func testSelectionAddsNothingWhenNothingIsSelectedInAnotherApp() async throws {
        try await addsNothing(over: "com.apple.Safari")
    }

    private func addsNothing(over app: String) async throws {
        try copy("selection")
        try witness()
        host.frontApp = FrontApp(bundleID: app)
        reads.set(front: app, answers: ["com.apple.finder": []])

        await open()
        try await wait("the end of the read") { self.model.sheets["selection"]?.isShowing == false && self.log("witness-log").count == 1 }

        XCTAssertEqual(chips, [])
        XCTAssertEqual(host.notes, [])
    }

    func testFreshCopyAddsACopiedLinkAsALink() async throws {
        try copy("fresh-copy")
        board.copy("https://a.com/x\n")

        await open()

        try await wait("the copy") { self.state(of: "fresh-copy") != nil }
        XCTAssertEqual(state(of: "fresh-copy"), .ready(AttachmentValue(url: "https://a.com/x")))
    }

    func testFreshCopyAddsOtherWordsAsCopiedText() async throws {
        try copy("fresh-copy")
        board.copy("see https://a.com/x")

        await open()

        try await wait("the copy") { self.state(of: "fresh-copy") != nil }
        XCTAssertEqual(state(of: "fresh-copy"), .ready(AttachmentValue(text: "see https://a.com/x", title: "Copied text")))
    }

    func testFreshCopyAddsNothingWhenTheClipboardHoldsNoText() async throws {
        try copy("fresh-copy")
        try witness()
        board.copy("  \n")

        await open()
        try await wait("the end of the read") { self.model.sheets["fresh-copy"]?.isShowing == false && self.log("witness-log").count == 1 }

        XCTAssertEqual(chips, [])
    }
}
