import XCTest
@testable import OpenspotCore

final class TimelineSpotTests: BuiltInCase {
    private var timeline: Spot {
        get throws {
            try spot("timeline")
        }
    }

    private let keptDays = "setting.keep=30 days\n"

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
          "timeline get") echo "$*" >> '\(log.path)'; printf 'whole of %s' "$3"; exit 0 ;;
          "clipboard paste" | "toast "* | "spot open") echo "$*" >> '\(log.path)'; exit 0 ;;
        esac
        exec '\(real.path)' "$@"
        """)
        try fake("open", "echo \"open $*\" >> '\(log.path)'")
        try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot"), withDestinationURL: repoSpots.appendingPathComponent("openspot.spot"))
        runs.take(try SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots).scan())
    }

    @discardableResult
    private func add(_ kind: AttachmentValue.Kind, _ value: String, at: Date = Date(), title: String? = nil) throws -> String {
        try XCTUnwrap(try runs.timeline.add(Timeline.Draft(kind: kind, values: [value], title: title), of: "clipboard", at: at)).id
    }

    private func rows(_ input: String? = nil) async throws -> [SpotItem] {
        try await timeline.items(input: input ?? keptDays, timeout: 60).items
    }

    func testTheRowsShowNewestFirstUnderTheirDay() async throws {
        let now = Date()
        try add(.text, "old\nnote", at: now.addingTimeInterval(-3 * 86_400))
        try add(.url, "https://a.com", at: now.addingTimeInterval(-60))
        try add(.text, "fresh", at: now)

        let rows = try await rows()

        XCTAssertEqual(rows.map(\.title), ["fresh", "https://a.com", "old"])
        XCTAssertEqual(rows.prefix(2).map(\.section), ["Today", "Today"])
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "EEEE, MMMM d"
        XCTAssertEqual(rows.last?.section, day.string(from: now.addingTimeInterval(-3 * 86_400)))
        XCTAssertEqual(rows.map(\.openTitle), ["Copy", "Copy", "Copy"])
        XCTAssertEqual(rows.map { $0.subtitle?.drop { $0 != "·" } }, ["· 5 characters", "· a.com", "· 2 lines"])
    }

    func testTheTitlesOfPastDaysStartNoProcessForEachDay() async throws {
        let calls = root.appendingPathComponent("dates")
        try fake("date", "echo date >> '\(calls.path)'\nexec /bin/date \"$@\"")
        let now = Date()
        for days in 2...5 { try add(.text, "day \(days)", at: now.addingTimeInterval(Double(-days) * 86_400)) }

        let rows = try await rows()

        XCTAssertEqual(Set(rows.compactMap(\.section)).count, 4)
        XCTAssertEqual(((try? String(contentsOf: calls, encoding: .utf8)) ?? "").split(separator: "\n").count, 0)
    }

    func testAFileOfAPictureShowsAsAnImageWithItselfAsItsIcon() async throws {
        try add(.file, "/tmp/shot.png")
        try add(.file, "/tmp/notes.txt", at: Date().addingTimeInterval(1))

        let rows = try await rows()

        XCTAssertEqual(rows.map { $0.subtitle?.drop { $0 != "·" } }, ["· File", "· Image"])
        XCTAssertEqual(rows.map(\.picture), [.symbol("doc"), .image("/tmp/shot.png")])
    }

    func testAFileOfAVideoShowsAsAVideoWithItselfAsItsIcon() async throws {
        try add(.file, "/tmp/clip.mov")

        let rows = try await rows()

        XCTAssertEqual(rows.map { $0.subtitle?.drop { $0 != "·" } }, ["· Video"])
        XCTAssertEqual(rows.map(\.picture), [.image("/tmp/clip.mov")])
    }

    func testAnEntryThatGivesItsIconAndDetailShowsThemOverThoseOfItsKind() async throws {
        try runs.timeline.add(Timeline.Draft(kind: .url, values: ["https://github.com/a/b/pull/12"], title: "Fix the cut", icon: "arrow.triangle.pull", detail: "Pull request #12"), of: "pulls", at: Date())

        let shown = try await rows()
        let row = try XCTUnwrap(shown.first)

        XCTAssertEqual(row.picture, .symbol("arrow.triangle.pull"))
        XCTAssertEqual(row.subtitle?.drop { $0 != "·" }, "· Pull request #12 · Pulls")
    }

    func testAColourShowsAsASquareOfItself() async throws {
        try add(.text, "#FF3B30")
        try add(.text, "#ff3b30 is red", at: Date().addingTimeInterval(1))
        try add(.text, "#666", at: Date().addingTimeInterval(2))

        let rows = try await rows()

        XCTAssertEqual(rows.map(\.color), ["#666666", nil, "#ff3b30"])
    }

    func testTheRowOfAnEntryWithAPeekCarriesItAndTheNextRowStaysItsOwn() async throws {
        let peek = TextBlock.blocks(in: "peek=p\n\ntext=hex\nparent=p\ntitle=#FF0000\n\nbutton=rgb\nparent=p\ntitle=Copy RGB\naction=clipboard copy --text rgb\n")
        let id = try XCTUnwrap(try runs.timeline.add(Timeline.Draft(kind: .text, values: ["#ff0000"], peek: peek), of: "clipboard", at: Date().addingTimeInterval(1))).id
        try add(.text, "plain")

        let rows = try await rows()

        XCTAssertEqual(rows.map(\.title), ["#ff0000", "plain"])
        let file = try XCTUnwrap(rows.first?.peekFile)
        let kept = TextBlock.blocks(in: try String(contentsOfFile: file, encoding: .utf8))
        XCTAssertEqual(kept.map(\.firstLine), ["peek=peek-\(id)", "text=hex", "button=rgb"])
        XCTAssertEqual(PeekAct.actions(of: kept).map(\.title), ["Copy RGB"])
        XCTAssertNil(rows.last?.peekFile)
    }

    func testTheSpotIsTitledTimelineAndNotByItsNewestEntry() async throws {
        try add(.text, "newest")

        let shown = try await timeline.items(input: "input.event=panel.open\n" + keptDays, timeout: 60)

        XCTAssertEqual(shown.root?.value("title"), "Timeline")
        XCTAssertFalse(try timeline.triggers.events.contains(EventName.panelOpen))
    }

    func testTheSheetKeepsTheTitleOfTheSpotAndNotOfTheNewestEntry() async throws {
        try add(.text, "Screenshot 2026-11-25 at 23.32.04.png")

        let frame = try await timeline.items(input: keptDays, timeout: 60)

        XCTAssertEqual(frame.root?.value("title"), "Timeline")
        XCTAssertEqual(frame.items.first?.title, "Screenshot 2026-11-25 at 23.32.04.png")
    }

    func testAnEmptyTimelineSaysHowToFillIt() async throws {
        let rows = try await rows()

        XCTAssertEqual(rows.map(\.title), ["Copy something, and it shows here."])
    }

    func testTheSheetShowsAPageAndATypedWordFindsAnEntryPastIt() async throws {
        let now = Date()
        try add(.text, "needle", at: now.addingTimeInterval(-3_600))
        for index in 0..<70 { try add(.text, "filler \(index)", at: now.addingTimeInterval(Double(index))) }

        let shown = try await rows()
        let found = try await timeline.answer("sheet.text", input: "input.value=needle\n", timeout: 60).items

        XCTAssertEqual(shown.count, 60)
        XCTAssertFalse(shown.contains { $0.title == "needle" })
        XCTAssertEqual(found.map(\.title), ["needle"])
    }

    func testMoreGivesThePageAfterTheLastRowAndNothingPastTheEnd() async throws {
        let now = Date()
        for index in 0..<70 { try add(.text, "filler \(index)", at: now.addingTimeInterval(Double(index))) }
        let shown = try await rows()

        let next = try await timeline.answer("sheet.more", input: "input.after=\(shown.last?.run ?? "")\n", timeout: 60).items
        let past = try await timeline.answer("sheet.more", input: "input.after=\(next.last?.run ?? "")\n", timeout: 60).items

        XCTAssertEqual(next.map(\.title), (0..<10).reversed().map { "filler \($0)" })
        XCTAssertEqual(past, [])
    }

    func testAWordThatNoEntryHoldsSaysSo() async throws {
        try add(.text, "hello")

        let found = try await timeline.answer("sheet.text", input: "input.value=zebra\n", timeout: 60).items

        XCTAssertEqual(found.map(\.title), ["Nothing you copied holds “zebra”."])
    }

    func testARowHoldsOnlyTheStartOfALongText() async throws {
        try add(.text, String(repeating: "a", count: 5_000))

        let row = try await rows().first

        XCTAssertEqual(row?.fields.first { $0.key == "text" }?.value.count, 2_000)
    }

    func testReturnCopiesAnEntryOfEachKind() async throws {
        try await timeline.perform("press", input: "input.item=a\ninput.item.kind=text\ninput.item.text=two\\nlines\n", timeout: 60)
        try await timeline.perform("press", input: "input.item=c\ninput.item.kind=file\ninput.item.file=/tmp/kept.txt\n", timeout: 60)
        try await timeline.perform("press", input: "input.item=empty\n", timeout: 60)

        XCTAssertEqual(effects, ["timeline get a", "clipboard copy |whole of a", "toast Copied.", "clipboard copy /tmp/kept.txt|", "toast Copied."])
    }

    func testCommandReturnPastesAnEntryAndALinkToo() async throws {
        try await timeline.perform("paste", input: "input.item=a\n", timeout: 60)
        try await timeline.perform("paste", input: "input.item=b\n", timeout: 60)

        XCTAssertEqual(effects, ["timeline get a", "clipboard copy |whole of a", "clipboard paste", "timeline get b", "clipboard copy |whole of b", "clipboard paste"])
    }

    func testTheSheetSaysCopyOnReturnAndOffersPasteOnCommandReturnAndATextShowsAa() async throws {
        try add(.text, "hello")

        let frame = try await timeline.items(input: keptDays, timeout: 60)

        XCTAssertEqual(frame.items.map(\.openTitle), ["Copy"])
        XCTAssertEqual(frame.items.map(\.picture), [.symbol("textformat")])
        XCTAssertEqual(frame.actions.first { $0.title == "Paste" }?.key, ActionKey(text: "cmd+return"))
        XCTAssertFalse(frame.actions.contains { $0.key == ActionKey(text: "cmd+c") }, "\(frame.actions.map(\.title))")
    }

    func testForgetTakesTheEntryOutAndTheToastPutsItBack() async throws {
        let id = try add(.text, "secret")

        try await timeline.perform("forget", input: "input.item=\(id)\n", timeout: 60)

        XCTAssertEqual((runs.timeline.list(Timeline.Query(), at: Date()) ?? []).count, 0)
        XCTAssertEqual(effects, ["toast --id forgot --action restore Forgot it. Click to put it back."])

        try await timeline.perform("restore", timeout: 60)

        XCTAssertEqual((runs.timeline.list(Timeline.Query(), at: Date()) ?? []).map(\.value), ["secret"])
    }

    func testAnOpenSetsTheDaysOfKeepForAndATypedWordSetsNone() async throws {
        _ = try await timeline.answer("sheet.text", input: "input.value=cafe\nsetting.keep=7 days\n", timeout: 60)
        XCTAssertEqual(runs.timeline.choices().keptDays, 30)

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

    func testAKeyStartsNoProcessWhileShowInSearchIsOff() async throws {
        runs.api = CommandAPI(mac: Mac(), places: .test(TestEnvironment.values), app: app, runs: runs)
        let programs = try countPrograms()
        try add(.text, "cafe latte")
        let message = ShowEvent.typed("cafe", inSheet: false).message()

        let answer = try await runs.answer(of: finder, message.handler, input: message.text, limit: 60)

        XCTAssertEqual(Frame(text: answer, kinds: try finder.kinds).items, [])
        XCTAssertEqual(programs(), [])
    }

    func testTheSearchAsksTheTimelineForThreeEntries() async throws {
        try file.change { $0.set(setting: "in-search", of: "openspot/timeline", to: "true") }
        let programs = try countPrograms()
        try add(.text, "cafe latte")

        _ = try await finder.items(query: "cafe", timeout: 60)

        XCTAssertTrue(programs().contains("openspot timeline list --all --limit 3 --search cafe"), "\(programs())")
    }

    func testTheSearchShowsTheThreeNewestEntriesThatHoldTheWords() async throws {
        try file.change { $0.set(setting: "in-search", of: "openspot/timeline", to: "true") }
        let now = Date()
        for index in 0..<4 { try add(.text, "cafe \(index)\nsecond line", at: now.addingTimeInterval(Double(index))) }
        try add(.url, "https://tea.com", at: now.addingTimeInterval(10))

        let rows = try await finder.items(query: "cafe", timeout: 60).items

        XCTAssertEqual(rows.map(\.title), ["cafe 3", "cafe 2", "cafe 1"])
        XCTAssertEqual(rows.first?.subtitle?.hasPrefix("Timeline · "), true)
        XCTAssertEqual(rows.first?.subtitle?.hasSuffix(" · 2 lines"), true)
        XCTAssertEqual(rows.first.flatMap(AttachmentValue.init(row:)), AttachmentValue(text: "cafe 3\nsecond line", title: "cafe 3"))
        XCTAssertEqual(rows.first?.openTitle, "Copy")
    }

    func testTheSearchShowsAColourAsASquareOfItself() async throws {
        try file.change { $0.set(setting: "in-search", of: "openspot/timeline", to: "true") }
        try add(.text, "#666")

        let rows = try await finder.items(query: "#666", timeout: 60).items

        XCTAssertEqual(rows.map(\.color), ["#666666"])
    }

    func testTheSearchShowsACopiedImageWithItselfAsItsIcon() async throws {
        try file.change { $0.set(setting: "in-search", of: "openspot/timeline", to: "true") }
        try add(.file, "/tmp/cafe.png")

        let rows = try await finder.items(query: "cafe", timeout: 60).items

        XCTAssertEqual(rows.map(\.picture), [.image("/tmp/cafe.png")])
        XCTAssertEqual(rows.first?.file, "/tmp/cafe.png")
    }

    func testReturnOnARowOfTheSearchCopiesItsEntry() async throws {
        try await finder.perform("press", input: "input.item=a\ninput.item.kind=text\n", timeout: 60)

        XCTAssertEqual(effects, ["timeline get a", "clipboard copy |whole of a", "toast Copied."])
    }
}
