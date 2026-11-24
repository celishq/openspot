import XCTest
@testable import OpenspotCore

@MainActor
final class ReadUseCallTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var api: CommandAPI!
    private let reads = FakeReads()

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
        api = CommandAPI(mac: Mac(reads: ReadSources(mac: reads)), places: .test(["OPENSPOT_CONFIG": folder.path]), runs: runs)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(uses: Set<SpotUse> = [.read]) -> Spot {
        Spot(id: "reader", name: "Reader", url: folder.appendingPathComponent("reader.sh"), dataName: "reader", uses: uses)
    }

    private func call(_ arguments: [String], from spot: Spot? = nil, reason: String? = nil) async throws -> CommandAnswer {
        let request = CommandRequest(arguments: arguments, folder: folder.path, caller: spot.map { runs.callers.issue(for: $0, reason: reason) })
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    func testTabPrintsTheFrontTabOfABrowserInTheWordsOfThatBrowser() async throws {
        reads.set(front: "com.apple.Safari", answers: ["com.apple.Safari": ["https://a.com/", "A page"], "com.google.Chrome": ["https://b.com/", "B page"]])
        let safari = try await call(["browser", "tab"])
        reads.set(front: "com.google.Chrome", answers: ["com.apple.Safari": ["https://a.com/", "A page"], "com.google.Chrome": ["https://b.com/", "B page"]])
        let chrome = try await call(["browser", "tab"])

        XCTAssertEqual(safari.output, "url=https://a.com/\ntitle=A page\napp=com.apple.Safari\n")
        XCTAssertEqual(chrome.output, "url=https://b.com/\ntitle=B page\napp=com.google.Chrome\n")
        XCTAssertEqual(reads.scripts.count, 2)
        XCTAssertTrue(reads.scripts[0].contains("current tab") && reads.scripts[0].contains("name of"), reads.scripts[0])
        XCTAssertTrue(reads.scripts[1].contains("active tab") && reads.scripts[1].contains("title of"), reads.scripts[1])
    }

    func testTabPrintsNothingWhenNoBrowserIsInFront() async throws {
        reads.set(front: "com.apple.TextEdit")

        let answer = try await call(["browser", "tab"])

        XCTAssertEqual([answer.output, answer.errors], ["", ""])
        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(reads.scripts, [])
    }

    func testTabOfABrowserReadsItsFrontWindowWhileAnotherAppIsInFront() async throws {
        reads.set(front: "com.apple.TextEdit", answers: ["com.google.Chrome": ["https://b.com/", "B page"]])

        let answer = try await call(["browser", "tab", "com.google.Chrome"])

        XCTAssertEqual(answer.output, "url=https://b.com/\ntitle=B page\napp=com.google.Chrome\n")
    }

    func testTabOfABrowserThatIsNotRunningPrintsNothingAndAsksNoScript() async throws {
        reads.set(front: "com.apple.TextEdit", access: ["com.apple.Safari": .unknown])

        let answer = try await call(["browser", "tab", "com.apple.Safari"])

        XCTAssertEqual([answer.output, answer.errors], ["", ""])
        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(reads.scripts, [])
    }

    func testTabOfAnAppThatIsNoBrowserFailsWithALineThatNamesTheBrowsers() async throws {
        for verb in ["tab", "tabs"] {
            let answer = try await call(["browser", verb, "com.apple.TextEdit"])

            XCTAssertEqual(answer.code, 1)
            XCTAssertTrue(answer.errors.hasPrefix("Openspot can't read the tabs of com.apple.TextEdit. Name a browser: com.apple.Safari, "), answer.errors)
            XCTAssertTrue(answer.errors.contains("com.google.Chrome"), answer.errors)
        }
        XCTAssertEqual(reads.scripts, [])
    }

    func testTabsPrintsARecordForEachTabOfEachWindowInOneScript() async throws {
        let tabs = ["https://a.com/", "A", "1", "1", "false", "https://b.com/", "", "1", "2", "true", "https://c.com/", "C", "2", "1", "true"]
        reads.set(front: "com.apple.Safari", answers: ["com.apple.Safari": tabs])

        let answer = try await call(["browser", "tabs"])

        XCTAssertEqual(answer.output, """
        url=https://a.com/
        title=A
        window=1
        index=1
        active=false
        app=com.apple.Safari

        url=https://b.com/
        window=1
        index=2
        active=true
        app=com.apple.Safari

        url=https://c.com/
        title=C
        window=2
        index=1
        active=true
        app=com.apple.Safari

        """)
        XCTAssertEqual(reads.scripts.count, 1)
        XCTAssertTrue(reads.scripts[0].contains("current tab") && reads.scripts[0].contains("name of"), reads.scripts[0])
    }

    func testTabsOfABrowserReadsItWhileAnotherAppIsInFrontAndInItsOwnWords() async throws {
        reads.set(front: "com.apple.TextEdit", answers: ["com.google.Chrome": ["https://b.com/", "B", "1", "1", "true"]])

        let named = try await call(["browser", "tabs", "com.google.Chrome"])
        let front = try await call(["browser", "tabs"])

        XCTAssertEqual(named.output, "url=https://b.com/\ntitle=B\nwindow=1\nindex=1\nactive=true\napp=com.google.Chrome\n")
        XCTAssertEqual(front.output, "")
        XCTAssertEqual(reads.scripts.count, 1)
        XCTAssertTrue(reads.scripts[0].contains("active tab") && reads.scripts[0].contains("title of"), reads.scripts[0])
    }

    func testFinderPrintsALineForEachSelectedFile() async throws {
        reads.set(answers: ["com.apple.finder": ["/Users/a/one.txt", "/Users/a/Two Words"]])

        let answer = try await call(["finder", "selection"])

        XCTAssertEqual(answer.output, "file=/Users/a/one.txt\nfile=/Users/a/Two Words\napp=com.apple.finder\n")
    }

    func testSelectionPrintsTheTextSelectedInTheFrontApp() async throws {
        reads.set(front: "com.apple.Notes", selected: "two\nlines")

        let answer = try await call(["selection", "read"])

        XCTAssertEqual(answer.output, "text=two\\nlines\napp=com.apple.Notes\n")
    }

    func testAppPrintsTheBundleIDNameAndPlaceOfTheFrontApp() async throws {
        reads.set(front: "com.apple.TextEdit")

        let answer = try await call(["window", "app"])

        XCTAssertEqual(answer.output, "app=com.apple.TextEdit\nname=TextEdit\npath=/Applications/TextEdit.app\n")
    }

    func testAppPrintsNothingWhenNoAppIsInFront() async throws {
        reads.set()

        let answer = try await call(["window", "app"])

        XCTAssertEqual([answer.output, answer.errors], ["", ""])
        XCTAssertEqual(answer.code, 0)
    }

    func testNothingToReadPrintsNothingAndEndsWell() async throws {
        reads.set(front: "com.apple.Safari", answers: ["com.apple.finder": []], selected: "  \n")

        for source in [["browser", "tab"], ["finder", "selection"], ["selection", "read"]] {
            let answer = try await call(source)
            XCTAssertEqual([answer.output, answer.errors], ["", ""], source.joined(separator: " "))
            XCTAssertEqual(answer.code, 0, source.joined(separator: " "))
        }
    }

    func testAReadThatIsNotAllowedFailsWithALineThatSaysWhereToAllowIt() async throws {
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .denied, "com.apple.finder": .denied], grant: .unasked, trust: .unasked)

        let answers = [try await call(["browser", "tab"]), try await call(["browser", "tabs"]), try await call(["finder", "selection"]), try await call(["selection", "read"])]

        XCTAssertEqual(answers.map(\.code), [1, 1, 1, 1])
        XCTAssertEqual(answers.map(\.errors), [
            "Openspot can't read Safari. Allow it in the Attachments spot.\n",
            "Openspot can't read Safari. Allow it in the Attachments spot.\n",
            "Openspot can't read Finder. Allow it in the Attachments spot.\n",
            "Openspot can't read the selected text. Allow it in the Attachments spot.\n"
        ])
        XCTAssertEqual(reads.scripts, [])
    }

    func testAReadOfAShowNeverAsksAndAPersonsRunOrTheTerminalMayAsk() async throws {
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .unasked], trust: .unasked, answers: ["com.apple.Safari": ["https://a.com/", "A"]], selected: "word")

        let show = try await call(["browser", "tab"], from: spot(), reason: "panel.open")
        let shownTabs = try await call(["browser", "tabs"], from: spot(), reason: "panel.open")
        let shownSelection = try await call(["selection", "read"], from: spot(), reason: "panel.open")
        let press = try await call(["browser", "tab"], from: spot())
        let terminal = try await call(["selection", "read"])

        XCTAssertEqual([show.code, shownTabs.code, shownSelection.code], [1, 1, 1])
        XCTAssertEqual(show.errors, "Openspot can't read Safari. Allow it in the Attachments spot.\n")
        XCTAssertEqual([press.code, terminal.code], [0, 0], press.errors + terminal.errors)
        XCTAssertEqual(reads.asks, ["com.apple.Safari false", "com.apple.Safari false", "accessibility false", "com.apple.Safari true", "accessibility true"])
    }

    func testInCarefulModeASpotWithoutReadInItsUsesIsRefused() async throws {
        runs.isCareful = true
        reads.set(front: "com.apple.Notes", selected: "words")

        let refused = try await call(["selection", "read"], from: spot(uses: [.screen]))
        let allowed = try await call(["selection", "read"], from: spot())

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "Careful mode stopped Reader, because it read what the person works on without `read` in the `uses` of its spot.toml. Add it, or turn Careful mode off.\n")
        XCTAssertEqual(allowed.output, "text=words\napp=com.apple.Notes\n")
    }

    func testAccessPrintsARecordForEachReaderAndNeverAsks() async throws {
        reads.set(installed: ["com.apple.Safari", "com.google.Chrome"], access: ["com.apple.Safari": .allowed, "com.google.Chrome": .unknown, "com.apple.finder": .unasked], trust: .unasked)

        let answer = try await call(["access", "list"])

        XCTAssertEqual(answer.output, """
        app=com.apple.Safari
        path=/Applications/Safari.app
        access=allowed

        app=com.google.Chrome
        path=/Applications/Chrome.app
        access=unknown

        app=com.apple.finder
        path=/Applications/Finder.app
        access=unasked

        app=accessibility
        access=unasked

        """)
        XCTAssertFalse(reads.asks.contains { $0.hasSuffix("true") }, reads.asks.joined(separator: ", "))
    }

    func testAskAsksForOneAppOrAccessibilityInAPersonsRunAndFailsInAShow() async throws {
        reads.set(installed: ["com.apple.Safari", "com.google.Chrome"], access: ["com.google.Chrome": .unasked], trust: .unasked)

        let shown = try await call(["access", "ask", "com.google.Chrome"], from: spot(), reason: "sheet.open")
        let press = try await call(["access", "ask", "com.google.Chrome"], from: spot())
        let trust = try await call(["access", "ask", "accessibility"], from: spot())

        XCTAssertEqual(shown.code, 1)
        XCTAssertEqual(press.output, "app=com.google.Chrome\npath=/Applications/Chrome.app\naccess=allowed\n")
        XCTAssertEqual(trust.output, "app=accessibility\naccess=allowed\n")
        XCTAssertEqual(reads.asks, ["com.google.Chrome true", "accessibility true"])
    }

    func testEachReadNeedsTheAppAndNamesItsUse() {
        for words in [["browser", "tab"], ["browser", "tab", "com.apple.Safari"], ["browser", "tabs"], ["finder", "selection"], ["selection", "read"], ["window", "app"], ["access", "list"], ["access", "ask", "accessibility"]] {
            XCTAssertEqual(SpotUseCall(arguments: words, of: "reader")?.use, .read, words.joined(separator: " "))
            XCTAssertTrue(CommandKind.needsApp(words), words.joined(separator: " "))
        }
        XCTAssertTrue(CommandLineCall(arguments: ["read", "tab"])?.value is CallFault)
        XCTAssertTrue(CommandLineCall(arguments: ["window", "selection"])?.value is CallFault)
    }
}
