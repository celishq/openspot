import XCTest
@testable import OpenspotCore

final class WidgetContractTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-widgets-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    private func script(_ name: String, _ text: String) throws {
        let url = folder.appendingPathComponent(name)
        try text.writeScript(to: url)
    }

    private func widgets(_ text: String, file: String = "mine.toml") throws {
        try text.write(to: folder.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    private func widget(name: String = "Now", grid: [String] = ["a a b b"], places: [String], more: String = "") throws {
        let lines = grid.map { "\"\($0)\"" }.joined(separator: ", ")
        let letters = ["a", "b", "c", "d"]
        let table = zip(letters, places).map { "\($0) = \"\($1)\"" }.joined(separator: ", ")
        try widgets("[[widgets]]\nname = \"\(name)\"\ngrid = [\(lines)]\nplaces = { \(table) }\n\(more)\n")
    }

    private func power(_ body: String = "printf 'gauge=power\\ntitle=84%%\\nvalue=0.84\\ntone=good\\n'") throws {
        try script("power.sh", "#!/bin/sh\n# read=5\n\(body)\n")
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    private func single(size: String?) throws {
        try power()
        try widget(grid: ["a"], places: ["power"], more: size.map { "size = \"\($0)\"" } ?? "")
    }

    func testAWidgetInAFolderNamesItsOwnToolsByFileNameAndOthersByID() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("morning"), withIntermediateDirectories: true)
        try script("morning/power.sh", "#!/bin/sh\n# read=5\nprintf 'title=1\\n'\n")
        try script("morning/notes.sh", "#!/bin/sh\n# read=sheet\n")
        try power()
        try "[[widgets]]\nname = \"Now\"\ngrid = [\"a a b b\"]\nplaces = { a = \"power\", b = \"morning/power\" }\nopens = \"notes\"\n"
            .write(to: folder.appendingPathComponent("morning/widgets.toml"), atomically: true, encoding: .utf8)

        let result = try scan
        let widget = try XCTUnwrap(result.commands.first { $0.kind == .widget })

        XCTAssertEqual(widget.places, ["morning/power", "morning/power"])
        XCTAssertEqual(widget.opens, "morning/notes")
        XCTAssertEqual(result.refused, [])
    }

    func testAOneLineDrawingIsAStripUnlessItAsksForAnotherSize() throws {
        try single(size: nil)
        XCTAssertEqual(try scan.commands.first?.size, .strip)
    }

    func testASingleWidgetCanAskToBeSmall() throws {
        try single(size: "small")
        XCTAssertEqual(try scan.commands.first?.size, .small)
    }

    func testASingleWidgetRefusesAnUnknownSize() throws {
        try single(size: "huge")
        XCTAssertEqual(try scan.refused.first?.reason, "Now has an unknown size: huge")
    }

    func testAPlaceTakesItsFormFromTheCardItFills() {
        let single = WidgetLayout(drawing: ["a"])
        let slot = single.slots[0]
        XCTAssertEqual(single.form(of: slot, on: .small), .control)
        XCTAssertEqual(single.form(of: slot, on: .wide), .half)
        XCTAssertEqual(single.form(of: slot, on: .strip), .half)
        XCTAssertEqual(single.form(of: slot, on: .square), .big)
    }

    func testOneBigPlaceBesideThreeLines() {
        let hero = WidgetLayout(drawing: ["a a b b", "a a c c", "a a d d"])
        XCTAssertEqual(hero.slots.map { hero.form(of: $0, on: .large) }, [.big, .line, .line, .line])
    }

    func testAPlaceInARowOrAPairTakesItsFormFromItsCell() {
        let row = WidgetLayout(drawing: ["a b c d"])
        let pair = WidgetLayout(drawing: ["a a b b"])
        XCTAssertEqual(row.slots.map { row.form(of: $0, on: .strip) }, [.stat, .stat, .stat, .stat])
        XCTAssertEqual(pair.slots.map { pair.form(of: $0, on: .strip) }, [.half, .half])
    }

    func testAWidgetWithADrawingPlacesAMetricOnEachLetter() throws {
        try power()
        try script("heat.sh", "#!/bin/sh\n# read=5\nprintf 'title=1\\n'\n")
        try widgets("""
        [[widgets]]
        name = "Mine"
        grid = ["a a b", "a a c"]
        places = { c = "power", a = "heat", b = "power" }
        """)

        let command = try XCTUnwrap(try scan.commands.first { $0.kind == .widget })

        XCTAssertEqual(command.places, ["heat", "power", "power"])
        XCTAssertEqual(command.size, .large)
        XCTAssertEqual(command.layout?.columns, 3)
        XCTAssertEqual(command.layout?.rows, 2)
        XCTAssertEqual(command.layout?.slots.first, SheetArea(x0: 0, x1: 1, y0: 0, y1: 1))
    }

    func testAWidgetDrawingCanAskForASize() throws {
        try power()
        try widgets("[[widgets]]\nname = \"Mine\"\ngrid = [\"a b\"]\nsize = \"wide\"\nplaces = { a = \"power\", b = \"power\" }\n")

        XCTAssertEqual(try scan.commands.first { $0.kind == .widget }?.size, .wide)
    }

    func testAOneLineDrawingIsAStrip() {
        XCTAssertEqual(WidgetLayout(drawing: ["a b c"]).size, .strip)
    }

    func testAWidgetDrawingNamesItsFault() throws {
        let cases: [(grid: String, places: String, reason: String)] = [
            ("\"a b\", \"a\"", "{ a = \"power\", b = \"power\" }", "Mine: each grid line needs the same number of columns"),
            ("\"a -\"", "{ a = \"power\" }", "Mine: a widget's grid cannot have a divider"),
            ("\"a b\", \"b a\"", "{ a = \"power\", b = \"power\" }", "Mine: the letter a is not a rectangle"),
            ("\"a b\"", "{ a = \"power\" }", "Mine needs a metric for the letter b"),
            ("\"a\"", "{ a = \"power\", z = \"power\" }", "Mine names the letter z, which its grid does not have")
        ]
        try power()
        for item in cases {
            try widgets("[[widgets]]\nname = \"Mine\"\ngrid = [\(item.grid)]\nplaces = \(item.places)\n")
            XCTAssertEqual(try scan.refused.first?.reason, item.reason)
        }
    }

    func testCellsKeepOneGapAndAWiderOneBetweenTheSides() throws {
        let room = CGSize(width: 300, height: 100)
        let hero = WidgetLayout(drawing: ["a a b b", "a a c c", "a a d d"])
        let rects = hero.slots.map { hero.rect(of: $0, in: room, gap: 8, sideGap: 20) }

        XCTAssertEqual(rects[1].minX - rects[0].maxX, 20, accuracy: 0.001)
        XCTAssertEqual(rects[2].minY - rects[1].maxY, 8, accuracy: 0.001)
        XCTAssertEqual(rects[3].maxY, 100, accuracy: 0.001)
        XCTAssertEqual(rects[3].maxX, 300, accuracy: 0.001)

        let three = WidgetLayout(drawing: ["a b c"])
        let cells = three.slots.map { three.rect(of: $0, in: room, gap: 8, sideGap: 20) }
        XCTAssertEqual(cells[1].minX - cells[0].maxX, 8, accuracy: 0.001)
        XCTAssertEqual(cells[0].width, cells[2].width, accuracy: 0.001)
        XCTAssertEqual(cells[2].maxX, 300, accuracy: 0.001)
    }

    func testAMetricPrintsItsValue() async throws {
        try power()
        let metric = try XCTUnwrap(try scan.metrics.first)

        let value = try await metric.read(timeout: 5)

        XCTAssertEqual(value, MetricValue(title: "84%", tone: .good, value: 0.84))
    }

    func testAMetricThatPrintsNonsenseFails() async throws {
        try power("echo nonsense")
        let metric = try XCTUnwrap(try scan.metrics.first)

        do {
            _ = try await metric.read(timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual(error as? PluginError, .badMetric)
        }
    }

    func testAMetricCanAskToShowInTheMenuBar() throws {
        try script("power.sh", "#!/bin/sh\n# read=5\n# tray=true\n")
        try script("other.sh", "#!/bin/sh\n# read=5\n")

        XCTAssertEqual(try scan.metrics.filter(\.isTray).map(\.id), ["power"])
    }

    func testOnlyAMetricCanShowInTheMenuBar() throws {
        try script("one.sh", "#!/bin/sh\n# tray=true\n")
        try script("two.sh", "#!/bin/sh\n# read=panel\n# tray=true\n")
        try script("three.sh", "#!/bin/sh\n# stay=true\n# tray=true\n")

        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "one", reason: "One needs a number in its read to show in the menu bar"),
            ScanResult.Refusal(file: "three", reason: "Three needs a number in its read to show in the menu bar"),
            ScanResult.Refusal(file: "two", reason: "Two needs a number in its read to show in the menu bar")
        ])
    }

    func testAWidgetFilePlacesMetricsOfOtherScripts() throws {
        try power()
        try widgets("""
        [[widgets]]
        name = "Now"
        grid = ["a a b b"]
        places = { a = "power", b = "power" }
        shortcut = "w"

        [[widgets]]
        name = "Then"
        grid = ["a"]
        places = { a = "power" }
        size = "square"
        """)

        let scan = try scan
        let widget = try XCTUnwrap(scan.commands.first)

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.commands.map(\.id), ["mine/Now", "mine/Then"])
        XCTAssertEqual(widget.kind, .widget)
        XCTAssertEqual(widget.size, .strip)
        XCTAssertEqual(widget.layout, WidgetLayout(drawing: ["a a b b"]))
        XCTAssertEqual(widget.places, ["power", "power"])
        XCTAssertEqual(widget.key?.name, "w")
    }

    func testAWidgetNeedsAMetricForEachLetter() throws {
        try widget(grid: ["a a b b", "a a c c"], places: ["power"])

        XCTAssertEqual(try scan.refused.first?.reason, "Now needs a metric for the letter b")
    }

    func testAWidgetWithANamedLayoutIsRefusedAndAskedForAGrid() throws {
        try widgets("[[widgets]]\nname = \"Now\"\nlayout = \"pair\"\nplaces = [\"power\", \"power\"]\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now needs a grid, such as grid = [\"a a b b\"]")
    }

    func testAWidgetThatNamesAMissingMetricIsLeftOutAndReported() throws {
        try widget(places: ["power", "none"])

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Now names no metric called power")])
    }

    func testAWidgetThatOpensAMissingCommandIsLeftOutAndReported() throws {
        try power()
        try widget(places: ["power", "power"], more: "opens = \"nothing\"")

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Now opens no command called nothing")])
    }

    func testAWidgetOffersEnterOnlyWhenItOpensSomething() {
        let url = URL(fileURLWithPath: "/tmp")
        let still = Spot(id: "a/b", name: "b", url: url, kind: .widget)
        let opening = Spot(id: "a/c", name: "c", url: url, kind: .widget, opens: "a/d")

        XCTAssertNil(still.primaryTitle(hasItem: false))
        XCTAssertEqual(opening.primaryTitle(hasItem: false), "Open")
    }

    func testALostKeyKeepsTheRestOfTheCommand() throws {
        try script("one.sh", "#!/bin/sh\n# shortcut=x\n# read=panel\n# global=true\n")
        try script("two.sh", "#!/bin/sh\n# shortcut=x\n# read=panel\n# global=true\n")

        XCTAssertEqual(try scan.commands.map(\.isGlobal), [true, true])
    }

    func testEveryLayoutFillsItsSizeWithNoOverlap() {
        for layout in [["a"], ["a a b b", "a a c c", "a a d d"], ["a a b b"], ["a b c d"]].map({ WidgetLayout(drawing: $0) }) {
            var cells = Set<[Int]>()
            for slot in layout.slots {
                for row in slot.y0...slot.y1 {
                    for column in slot.x0...slot.x1 {
                        XCTAssertTrue(cells.insert([row, column]).inserted, layout.name)
                    }
                }
            }
            XCTAssertEqual(cells.count, layout.columns * layout.rows, layout.name)
        }
    }

    func testAFailedReadKeepsTheLastValueAndMarksItStale() {
        var reading = MetricReading(label: "Cups")
        reading.take(MetricValue(title: "3"))
        reading.markStale()

        XCTAssertEqual(reading.value?.title, "3")
        XCTAssertTrue(reading.isStale)

        reading.take(MetricValue(title: "4"))
        XCTAssertFalse(reading.isStale)
    }

    func testAGaugeStaysBetweenEmptyAndFull() {
        XCTAssertEqual(MetricValue(title: "", value: 2).fill, 1)
        XCTAssertEqual(MetricValue(title: "", value: -1).fill, 0)
    }

    func testATrendScalesFromZeroToItsHighest() {
        XCTAssertEqual(MetricValue(title: "", points: [10, 20, 40]).scaledPoints, [0.25, 0.5, 1])
        XCTAssertEqual(MetricValue(title: "", points: [7, 7]).scaledPoints, [1, 1])
        XCTAssertEqual(MetricValue(title: "", points: [0, 0]).scaledPoints, [0, 0])
    }

    func testATrendWithATopValueScalesToIt() {
        XCTAssertEqual(MetricValue(title: "", points: [25, 50], max: 100).scaledPoints, [0.25, 0.5])
    }

    func testAPointAboveTheTopValueStaysFull() {
        XCTAssertEqual(MetricValue(title: "", points: [50, 200], max: 100).scaledPoints, [0.5, 1])
    }

    func testTheCheckReportsNoFaultsForAGoodFolder() async throws {
        try power()

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
    }

    func testATomlFaultNamesItsLine() throws {
        try widgets("[[widgets]]\nnot a pair\n")

        XCTAssertEqual(try scan.refused, [ScanResult.Refusal(file: "mine", reason: "line 2: expected a key and a value")])
    }

    func testTheCheckReportsARefusedHeaderAndABadMetric() async throws {
        try power("echo nonsense")
        try script("broken.sh", "#!/bin/sh\n# size=huge\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["broken: Broken has an unknown size: huge", "power: It sent a metric Openspot cannot read."])
    }

    func testTheCheckReportsAListThatFails() async throws {
        try script("tools.sh", "#!/bin/sh\n# read=sheet\necho gone >&2\nexit 1\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: gone"])
    }

    func testTheCheckFaultsAPartOrAnActionCalledRead() async throws {
        try script("tools.sh", "#!/bin/sh\n# read=sheet\nprintf 'button=read\\ntitle=A\\n\\nrow=a\\ntitle=A\\n\\ntext=read\\ntitle=B\\n'\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: an action cannot be called read", "tools: a part cannot be called read"])
    }

    func testTheCheckDoesNotRunAScriptWithNoRead() async throws {
        let marker = folder.appendingPathComponent("marker")
        try script("once.sh", "#!/bin/sh\ntouch '\(marker.path)'\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
