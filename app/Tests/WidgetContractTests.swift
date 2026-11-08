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

    private func widget(name: String = "Now", layout: String, places: [String], more: String = "") throws {
        let list = places.map { "\"\($0)\"" }.joined(separator: ", ")
        try widgets("[[widgets]]\nname = \"\(name)\"\nlayout = \"\(layout)\"\nplaces = [\(list)]\n\(more)\n")
    }

    private func power(_ body: String = "printf 'title=84%%\\nvalue=0.84\\ntone=good\\n'") throws {
        try script("power.sh", "#!/bin/sh\n# read=5\n\(body)\n")
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    private func single(size: String?, layout: String = "single", places: Int = 1) throws {
        try power()
        try widget(layout: layout, places: Array(repeating: "power", count: places), more: size.map { "size = \"\($0)\"" } ?? "")
    }

    func testASingleWidgetIsSquareUnlessItAsksForAnotherSize() throws {
        try single(size: nil)
        XCTAssertEqual(try scan.commands.first?.size, .square)
    }

    func testASingleWidgetCanAskToBeSmall() throws {
        try single(size: "small")
        XCTAssertEqual(try scan.commands.first?.size, .small)
    }

    func testOnlyASingleWidgetTakesASize() throws {
        try single(size: "small", layout: "pair", places: 2)
        XCTAssertEqual(try scan.refused.first?.reason, "Now cannot take a size, because the pair layout sets its own")
    }

    func testASingleWidgetRefusesAnUnknownSize() throws {
        try single(size: "huge")
        XCTAssertEqual(try scan.refused.first?.reason, "Now has an unknown size: huge")
    }

    func testAPlaceTakesItsFormFromTheCardItFills() {
        let slot = WidgetLayout.single.slots[0]
        XCTAssertEqual(WidgetLayout.single.form(of: slot, on: .small), .control)
        XCTAssertEqual(WidgetLayout.single.form(of: slot, on: .wide), .half)
        XCTAssertEqual(WidgetLayout.single.form(of: slot, on: .strip), .half)
        XCTAssertEqual(WidgetLayout.single.form(of: slot, on: .square), .big)
    }

    func testAHeroHasOneBigPlaceAndThreeLines() {
        XCTAssertEqual(WidgetLayout.hero.slots.map { WidgetLayout.hero.form(of: $0, on: .large) }, [.big, .line, .line, .line])
    }

    func testAPlaceInARowOrAPairTakesItsFormFromItsCell() {
        XCTAssertEqual(WidgetLayout.row.slots.map { WidgetLayout.row.form(of: $0, on: .strip) }, [.stat, .stat, .stat, .stat])
        XCTAssertEqual(WidgetLayout.pair.slots.map { WidgetLayout.pair.form(of: $0, on: .strip) }, [.half, .half])
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
        let hero = WidgetLayout.hero
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

    func testOnlyAMetricOrAStayingScriptCanShowInTheMenuBar() throws {
        try script("one.sh", "#!/bin/sh\n# tray=true\n")
        try script("two.sh", "#!/bin/sh\n# read=panel\n# tray=true\n")
        try script("three.sh", "#!/bin/sh\n# stay=true\n# tray=true\n")

        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "one", reason: "One needs a number in its read, or stay=true, to show in the menu bar"),
            ScanResult.Refusal(file: "two", reason: "Two needs a number in its read, or stay=true, to show in the menu bar")
        ])
    }

    func testAWidgetFilePlacesMetricsOfOtherScripts() throws {
        try power()
        try widgets("""
        [[widgets]]
        name = "Now"
        layout = "pair"
        places = ["power", "power"]
        key = "w"

        [[widgets]]
        name = "Then"
        layout = "single"
        places = ["power"]
        """)

        let scan = try scan
        let widget = try XCTUnwrap(scan.commands.first)

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.commands.map(\.id), ["mine/Now", "mine/Then"])
        XCTAssertEqual(widget.kind, .widget)
        XCTAssertEqual(widget.size, .strip)
        XCTAssertEqual(widget.layout, .pair)
        XCTAssertEqual(widget.places, ["power", "power"])
        XCTAssertEqual(widget.key?.name, "w")
    }

    func testAWidgetNeedsOnePlaceForEachSlot() throws {
        try widget(layout: "hero", places: ["power"])

        XCTAssertEqual(try scan.refused.first?.reason, "Now needs 4 places for the hero layout")
    }

    func testAnUnknownLayoutIsRefusedAndNamesTheChoices() throws {
        try widget(layout: "circle", places: ["power"])

        XCTAssertEqual(try scan.refused.first?.reason, "Now has an unknown layout: circle. Use single, hero, pair or row")
    }

    func testAWidgetThatNamesAMissingMetricIsLeftOutAndReported() throws {
        try widget(layout: "pair", places: ["power", "none"])

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Now names no metric called power")])
    }

    func testAWidgetThatOpensAMissingCommandIsLeftOutAndReported() throws {
        try power()
        try widget(layout: "pair", places: ["power", "power"], more: "opens = \"nothing\"")

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
        try script("one.sh", "#!/bin/sh\n# key=x\n# read=panel\n# rank=1\n")
        try script("two.sh", "#!/bin/sh\n# key=x\n# read=panel\n# rank=2\n")

        XCTAssertEqual(try scan.commands.map(\.rank), [1, 2])
    }

    func testEveryLayoutFillsItsSizeWithNoOverlap() {
        for layout in WidgetLayout.all {
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
        try script("tools.sh", "#!/bin/sh\n# read=sheet\nprintf 'action=read\\ntitle=A\\n\\nrow=A\\nrun=a\\n\\npart=read\\ntitle=B\\n'\n")

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
