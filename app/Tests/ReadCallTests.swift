import XCTest
@testable import OpenspotCore

@MainActor
final class ReadCallTests: XCTestCase {
    private final class Time: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Date(timeIntervalSince1970: 1000)

        var now: Date { lock.withLock { value } }

        func pass(_ seconds: TimeInterval) {
            lock.withLock { value += seconds }
        }
    }

    private var folder: URL!
    private var runs: SpotRuns!
    private var api: CommandAPI!
    private let reads = FakeReads()
    private let time = Time()

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
        api = CommandAPI(mac: Mac(reads: ReadSources(mac: reads, now: { [time] in time.now })), places: .test(["OPENSPOT_CONFIG": folder.path]), runs: runs)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(uses: Set<SpotUse> = [.read]) -> Spot {
        Spot(id: "reader", name: "Reader", url: folder.appendingPathComponent("reader.sh"), dataName: "reader", uses: uses)
    }

    private func call(_ arguments: [String], from spot: Spot? = nil, reason: String? = nil) async throws -> CommandAnswer {
        let request = CommandRequest(arguments: ["read"] + arguments, folder: folder.path, caller: spot.map { runs.callers.issue(for: $0, reason: reason) })
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    func testTabPrintsTheFrontTabOfABrowserInTheWordsOfThatBrowser() async throws {
        reads.set(front: "com.apple.Safari", answers: ["com.apple.Safari": ["https://a.com/", "A page"], "com.google.Chrome": ["https://b.com/", "B page"]])
        let safari = try await call(["tab"])
        reads.set(front: "com.google.Chrome", answers: ["com.apple.Safari": ["https://a.com/", "A page"], "com.google.Chrome": ["https://b.com/", "B page"]])
        let chrome = try await call(["tab"])

        XCTAssertEqual(safari.output, "url=https://a.com/\ntitle=A page\napp=com.apple.Safari\n")
        XCTAssertEqual(chrome.output, "url=https://b.com/\ntitle=B page\napp=com.google.Chrome\n")
        XCTAssertEqual(reads.scripts.count, 2)
        XCTAssertTrue(reads.scripts[0].contains("current tab") && reads.scripts[0].contains("name of"), reads.scripts[0])
        XCTAssertTrue(reads.scripts[1].contains("active tab") && reads.scripts[1].contains("title of"), reads.scripts[1])
    }

    func testTabPrintsNothingWhenNoBrowserIsInFront() async throws {
        reads.set(front: "com.apple.TextEdit")

        let answer = try await call(["tab"])

        XCTAssertEqual([answer.output, answer.errors], ["", ""])
        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(reads.scripts, [])
    }

    func testFinderPrintsALineForEachSelectedFile() async throws {
        reads.set(answers: ["com.apple.finder": ["/Users/a/one.txt", "/Users/a/Two Words"]])

        let answer = try await call(["finder"])

        XCTAssertEqual(answer.output, "file=/Users/a/one.txt\nfile=/Users/a/Two Words\napp=com.apple.finder\n")
    }

    func testSelectionPrintsTheTextSelectedInTheFrontApp() async throws {
        reads.set(front: "com.apple.Notes", selected: "two\nlines")

        let answer = try await call(["selection"])

        XCTAssertEqual(answer.output, "text=two\\nlines\napp=com.apple.Notes\n")
    }

    func testClipboardPrintsALinkOrTextWithTheSecondsSinceOpenspotFirstSawTheCopy() async throws {
        reads.copy("https://a.com/x\n", count: 5)
        let first = try await call(["clipboard"])
        time.pass(30)
        let later = try await call(["clipboard"])
        reads.copy("see https://a.com/x", count: 6)
        let text = try await call(["clipboard"])
        reads.copy(String(repeating: "é", count: 60_000), count: 7)
        let long = try await call(["clipboard"])

        XCTAssertEqual([first.output, later.output, text.output], ["url=https://a.com/x\nage=0\n", "url=https://a.com/x\nage=30\n", "text=see https://a.com/x\nage=0\n"])
        XCTAssertEqual(TextBlock.blocks(in: long.output).first?.value("text")?.utf8.count, 100_000)
    }

    func testNothingToReadPrintsNothingAndEndsWell() async throws {
        reads.set(front: "com.apple.Safari", answers: ["com.apple.finder": []], selected: "  \n")
        reads.copy(nil, count: 1)

        for source in ["tab", "finder", "selection", "clipboard"] {
            let answer = try await call([source])
            XCTAssertEqual([answer.output, answer.errors], ["", ""], source)
            XCTAssertEqual(answer.code, 0, source)
        }
    }

    func testAReadThatIsNotAllowedFailsWithALineThatSaysWhereToAllowIt() async throws {
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .denied, "com.apple.finder": .denied], grant: .unasked, trust: .unasked)

        let answers = [try await call(["tab"]), try await call(["finder"]), try await call(["selection"])]

        XCTAssertEqual(answers.map(\.code), [1, 1, 1])
        XCTAssertEqual(answers.map(\.errors), [
            "Openspot can't read Safari. Allow it in the Attachments spot.\n",
            "Openspot can't read Finder. Allow it in the Attachments spot.\n",
            "Openspot can't read the selected text. Allow it in the Attachments spot.\n"
        ])
        XCTAssertEqual(reads.scripts, [])
    }

    func testAReadOfAShowNeverAsksAndAPersonsRunOrTheTerminalMayAsk() async throws {
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .unasked], trust: .unasked, answers: ["com.apple.Safari": ["https://a.com/", "A"]], selected: "word")

        let show = try await call(["tab"], from: spot(), reason: "panel.open")
        let shownSelection = try await call(["selection"], from: spot(), reason: "panel.open")
        let press = try await call(["tab"], from: spot())
        let terminal = try await call(["selection"])

        XCTAssertEqual([show.code, shownSelection.code], [1, 1])
        XCTAssertEqual(show.errors, "Openspot can't read Safari. Allow it in the Attachments spot.\n")
        XCTAssertEqual([press.code, terminal.code], [0, 0], press.errors + terminal.errors)
        XCTAssertEqual(reads.asks, ["com.apple.Safari false", "accessibility false", "com.apple.Safari true", "accessibility true"])
    }

    func testInCarefulModeASpotWithoutReadInItsUsesIsRefused() async throws {
        runs.isCareful = true
        reads.copy("words", count: 1)

        let refused = try await call(["clipboard"], from: spot(uses: [.clipboard]))
        let allowed = try await call(["clipboard"], from: spot())

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "Careful mode stopped Reader, because it read what the person works on without `read` in the `uses` of its spot.toml. Add it, or turn Careful mode off.\n")
        XCTAssertEqual(allowed.output, "text=words\nage=0\n")
    }

    func testAccessPrintsARecordForEachReaderAndNeverAsks() async throws {
        reads.set(installed: ["com.apple.Safari", "com.google.Chrome"], access: ["com.apple.Safari": .allowed, "com.google.Chrome": .unknown, "com.apple.finder": .unasked], trust: .unasked)

        let answer = try await call(["--access"])

        XCTAssertEqual(answer.output, """
        reader=tab
        app=com.apple.Safari
        access=allowed

        reader=tab
        app=com.google.Chrome
        access=unknown

        reader=finder
        app=com.apple.finder
        access=unasked

        reader=selection
        access=unasked

        """)
        XCTAssertFalse(reads.asks.contains { $0.hasSuffix("true") }, reads.asks.joined(separator: ", "))
    }

    func testReadNeedsTheAppAndNamesItsUse() {
        XCTAssertEqual(SpotUseCall(arguments: ["read", "tab"], of: "reader")?.use, .read)
        XCTAssertTrue(CommandKind.needsApp(["read", "clipboard"]))
    }
}
