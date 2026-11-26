import XCTest
@testable import OpenspotCore

final class TimelineSpotTests: BuiltInCase {
    private var timeline: Spot {
        get throws {
            try spot("timeline")
        }
    }

    private var log: URL {
        root.appendingPathComponent("effects")
    }

    private var effects: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    override func setUp() async throws {
        try await super.setUp()
        let real = tools.appendingPathComponent("openspot-app")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", """
        case "$1 $2" in
          "clipboard copy") printf 'clipboard copy %s|%s\\n' "$3" "$(cat)" >> '\(log.path)'; exit 0 ;;
          "clipboard paste" | "toast "* | "spot open") echo "$*" >> '\(log.path)'; exit 0 ;;
        esac
        exec '\(real.path)' "$@"
        """)
        try fake("open", "echo \"open $*\" >> '\(log.path)'")
    }

    @discardableResult
    private func add(_ kind: TimelineEntry.Kind, _ value: String, at: Date = Date(), title: String? = nil) throws -> String {
        try XCTUnwrap(try runs.timeline.add(Timeline.Draft(kind: kind, values: [value], title: title), of: "clipboard", at: at)).id
    }

    private func rows(_ input: String? = nil) async throws -> [SpotItem] {
        try await timeline.items(input: input, timeout: 60).items
    }

    func testTheRowsShowNewestFirstUnderTheirDay() async throws {
        let now = Date()
        try add(.text, "old\nnote", at: now.addingTimeInterval(-3 * 86_400))
        try add(.url, "https://a.com", at: now.addingTimeInterval(-60))
        try add(.text, "fresh", at: now)

        let rows = try await rows()

        XCTAssertEqual(rows.map(\.title), ["fresh", "https://a.com", "old"])
        XCTAssertEqual(rows.prefix(2).map(\.section), ["Today", "Today"])
        let older = try XCTUnwrap(rows.last?.section)
        XCTAssertFalse(["Today", "Yesterday"].contains(older), older)
        XCTAssertFalse(older.contains("  "), older)
        XCTAssertEqual(rows.map(\.openTitle), ["Paste", "Open", "Paste"])
        XCTAssertEqual(rows.map { $0.subtitle?.drop { $0 != "·" } }, ["· 5 characters", "· a.com", "· 2 lines"])
    }

    func testTheCardShowsTheNewestEntry() async throws {
        try add(.text, "older", at: Date().addingTimeInterval(-60))
        try add(.text, "newest")

        let card = try await timeline.items(input: "input.event=panel.open\n", timeout: 60)

        XCTAssertEqual(card.root?.value("title"), "newest")
    }

    func testTheSheetKeepsTheTitleOfTheSpotAndNotOfTheNewestEntry() async throws {
        try add(.text, "Screenshot 2026-11-25 at 23.32.04.png")

        let frame = try await timeline.items(timeout: 60)

        XCTAssertEqual(frame.root?.value("title"), "Timeline")
        XCTAssertEqual(frame.items.first?.title, "Screenshot 2026-11-25 at 23.32.04.png")
    }

    func testAnEmptyTimelineSaysHowToFillIt() async throws {
        let rows = try await rows()

        XCTAssertEqual(rows.map(\.title), ["Copy something, and it shows here."])
    }

    func testATypedWordFindsAnEntryOlderThanTheNewestFiveHundred() async throws {
        let now = Date()
        try add(.text, "needle", at: now.addingTimeInterval(-3_600))
        for index in 0..<500 { try add(.text, "filler \(index)", at: now.addingTimeInterval(Double(index))) }

        let shown = try await rows()
        let found = try await timeline.answer("sheet.text", input: "input.value=needle\n", timeout: 60).items

        XCTAssertEqual(shown.count, 500)
        XCTAssertFalse(shown.contains { $0.title == "needle" })
        XCTAssertEqual(found.map(\.title), ["needle"])
    }

    func testReturnOnATextCopiesAndPastesIt() async throws {
        try await timeline.perform("press", input: "input.item=a\ninput.item.kind=text\ninput.item.text=two\\nlines\n", timeout: 60)

        XCTAssertEqual(effects, ["clipboard copy |two", "lines", "clipboard paste"])
    }

    func testReturnOnAFileCopiesTheFileAndPastesIt() async throws {
        try await timeline.perform("press", input: "input.item=a\ninput.item.kind=file\ninput.item.file=/tmp/kept.txt\n", timeout: 60)

        XCTAssertEqual(effects, ["clipboard copy /tmp/kept.txt|", "clipboard paste"])
    }

    func testReturnOnALinkOpensIt() async throws {
        try await timeline.perform("press", input: "input.item=a\ninput.item.kind=url\ninput.item.url=https://a.com\n", timeout: 60)

        XCTAssertEqual(effects, ["open -- https://a.com"])
    }

    func testReturnOnALinkThatIsNotOfTheWebPastesItAndOpensNothing() async throws {
        try await timeline.perform("press", input: "input.item=a\ninput.item.kind=url\ninput.item.url=file:///Applications/Calculator.app\n", timeout: 60)

        XCTAssertEqual(effects, ["clipboard copy |file:///Applications/Calculator.app", "clipboard paste"])
    }

    func testCopyCopiesWithNoPaste() async throws {
        try await timeline.perform("copy", input: "input.item=a\ninput.item.kind=url\ninput.item.url=https://a.com\n", timeout: 60)

        XCTAssertEqual(effects, ["clipboard copy |https://a.com", "toast Copied."])
    }

    func testForgetTakesTheEntryOutAndTheToastPutsItBack() async throws {
        let id = try add(.text, "secret")

        try await timeline.perform("forget", input: "input.item=\(id)\n", timeout: 60)

        XCTAssertEqual(runs.timeline.list(Timeline.Query(), at: Date()).count, 0)
        XCTAssertEqual(effects, ["toast --id forgot --action restore Forgot it. Click to put it back."])

        try await timeline.perform("restore", timeout: 60)

        XCTAssertEqual(runs.timeline.list(Timeline.Query(), at: Date()).map(\.value), ["secret"])
    }

    func testKeepForSetsTheDaysOfTheTimeline() async throws {
        _ = try await rows("setting.keep=7 days\n")

        XCTAssertEqual(runs.timeline.choices().keptDays, 7)
    }

    func testPauseKeepsNothingForAnHour() async throws {
        try await timeline.perform("pause", timeout: 60)

        let added = try runs.timeline.add(Timeline.Draft(kind: .text, values: ["hidden"]), of: "clipboard", at: Date())
        XCTAssertNil(added)

        try await timeline.perform("resume", timeout: 60)
        XCTAssertNotNil(try runs.timeline.add(Timeline.Draft(kind: .text, values: ["kept"]), of: "clipboard", at: Date()))
    }

    func testTheCommandOpensTheSheet() async throws {
        try await timeline.perform("command", input: "input.name=timeline\n", timeout: 60)

        XCTAssertEqual(effects, ["spot open openspot/timeline"])
    }

    private var finder: Spot {
        get throws {
            try spot("timeline-search")
        }
    }

    func testTheSearchShowsNoEntryWhileShowInSearchIsOff() async throws {
        try add(.text, "cafe latte")

        let rows = try await finder.items(query: "cafe", timeout: 60).items

        XCTAssertEqual(rows, [])
    }

    func testTheSearchShowsTheThreeNewestEntriesThatHoldTheWords() async throws {
        try file.change { $0.set(setting: "in-search", of: "openspot/timeline", to: "true") }
        let now = Date()
        for index in 0..<4 { try add(.text, "cafe \(index)\nsecond line", at: now.addingTimeInterval(Double(index))) }
        try add(.url, "https://tea.com", at: now.addingTimeInterval(10))

        let rows = try await finder.items(query: "cafe", timeout: 60).items

        XCTAssertEqual(rows.map(\.title), ["cafe 3", "cafe 2", "cafe 1"])
        XCTAssertEqual(rows.first?.subtitle?.hasPrefix("Timeline · Clipboard · "), true)
        XCTAssertEqual(rows.first?.handedValue(), AttachmentValue(text: "cafe 3\nsecond line", title: "cafe 3"))
        XCTAssertEqual(rows.first?.openTitle, "Paste")
    }

    func testUsePastesATextAndOpensALinkAsReturnInTheSheetDoes() async throws {
        try await timeline.perform("use", input: "input.kind=text\ninput.text=hello\n", timeout: 60)
        try await timeline.perform("use", input: "input.kind=url\ninput.url=https://a.com\n", timeout: 60)

        XCTAssertEqual(effects, ["clipboard copy |hello", "clipboard paste", "open -- https://a.com"])
    }
}
