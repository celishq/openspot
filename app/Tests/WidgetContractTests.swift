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

    /// A spot whose header draws its card from other spots, at a strip for one line and else large, unless a size is given.
    private func widget(name: String = "Now", grid: [String] = ["power power"], size: String? = nil, more: String = "", file: String = "mine.sh") throws {
        let size = size ?? (grid.count == 1 ? "strip" : "large")
        let lines = grid.map { "# grid.\(size)=\($0)\n" }.joined()
        try script(file, "#!/bin/sh\n# title=\(name)\n\(lines)\(more)")
    }

    private func power(_ body: String = "printf 'graph=power\\ntitle=84%%\\nvalue=0.84\\ntone=good\\n'") throws {
        try script("power.sh", "#!/bin/sh\n# on=clock.5\n\(body)\n")
    }

    private var scan: ScanResult {
        get throws { try SpotFolder(url: folder).scan() }
    }

    private func single(size: String?) throws {
        try power()
        try widget(grid: ["power"], size: size)
    }

    func testAWidgetInAFolderNamesItsOwnToolsByFileNameAndOthersByID() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("morning"), withIntermediateDirectories: true)
        try script("morning/power.sh", "#!/bin/sh\n# on=clock.5\nprintf 'title=1\\n'\n")
        try script("morning/notes.sh", "#!/bin/sh\n# on=sheet.open\n")
        try power()
        try widget(grid: ["power power morning/power morning/power"], more: "# to=notes\n", file: "morning/widgets.sh")

        let result = try scan
        let widget = try XCTUnwrap(result.spots.first { $0.kind == .widget })

        XCTAssertEqual(widget.places, ["morning/power", "morning/power"])
        XCTAssertEqual(widget.opens, "morning/notes")
        XCTAssertEqual(result.refused, [])
    }

    func testTheSizeOfTheDrawingKeyIsTheSizeOfTheCard() throws {
        try single(size: nil)
        XCTAssertEqual(try scan.spots.first?.size, .strip)
    }

    func testASingleWidgetCanAskToBeSmall() throws {
        try single(size: "small")
        XCTAssertEqual(try scan.spots.first?.size, .small)
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

    func testAWidgetDrawingPlacesTheMetricThatEachWordNames() throws {
        try power()
        try script("heat.sh", "#!/bin/sh\n# on=clock.5\nprintf 'title=1\\n'\n")
        try widget(name: "Mine", grid: ["heat heat power", "heat heat power"])

        let command = try XCTUnwrap(try scan.spots.first { $0.kind == .widget })

        XCTAssertEqual(command.places, ["heat", "power"])
        XCTAssertEqual(command.size, .large)
        XCTAssertEqual(command.layout?.columns, 3)
        XCTAssertEqual(command.layout?.rows, 2)
        XCTAssertEqual(command.layout?.slots.first, SheetArea(x0: 0, x1: 1, y0: 0, y1: 1))
    }

    func testAWidgetDrawingCanAskForASize() throws {
        try power()
        try widget(name: "Mine", grid: ["power power"], size: "wide")

        XCTAssertEqual(try scan.spots.first { $0.kind == .widget }?.size, .wide)
    }

    func testAOneLineDrawingIsAStrip() {
        XCTAssertEqual(WidgetLayout(drawing: ["a b c"]).size, .strip)
    }

    func testAWidgetDrawingNamesItsFault() throws {
        let cases: [(grid: [String], reason: String)] = [
            (["power heat", "power"], "Mine: each grid line needs the same number of columns"),
            (["power -"], "Mine: a widget's grid cannot have a divider"),
            (["power heat", "heat power"], "Mine: the metric power is not a rectangle")
        ]
        try power()
        for item in cases {
            try widget(name: "Mine", grid: item.grid)
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
            XCTAssertEqual(error as? SpotError, .badMetric)
        }
    }

    func testOnlyAMetricOrAStayingScriptCanShowInTheMenuBar() throws {
        try script("one.sh", "#!/bin/sh\n")
        try script("two.sh", "#!/bin/sh\n# on=panel.open\n")
        try script("three.sh", "#!/bin/sh\n# mode=stay\n")
        try script("four.sh", "#!/bin/sh\n# on=clock.5\n")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.scripts.filter(\.canShowInMenuBar).map(\.id), ["four", "three"])
    }

    func testASpotWhoseHeaderDrawsItsCardPlacesMetricsOfOtherScripts() throws {
        try power()
        try widget(grid: ["power power"])
        try widget(name: "Then", grid: ["power"], size: "square", file: "then.sh")

        let scan = try scan
        let widget = try XCTUnwrap(scan.spots.first)

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.spots.map(\.id), ["mine", "power", "then"])
        XCTAssertEqual(scan.spots.map(\.headerState.isOnGrid), [true, false, true])
        XCTAssertEqual(widget.kind, .widget)
        XCTAssertEqual(widget.size, .strip)
        XCTAssertEqual(widget.layout, WidgetLayout(drawing: ["power power"]))
        XCTAssertEqual(widget.places, ["power"])
    }

    func testAWidgetFileIsRefusedAndToldToBeASpot() throws {
        try "[[widgets]]\ntitle = \"Now\"\ngrid = [\"power\"]\n".write(to: folder.appendingPathComponent("mine.toml"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try scan.refused.first?.reason, "mine.toml holds widgets, which Openspot no longer reads. Write a spot whose header draws its card from other spots, such as grid.large=cpu cpu memory")
    }

    func testACardDrawnAtTwoSizesIsRefused() throws {
        try power()
        try widget(grid: ["power"], more: "# grid.large=power\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now draws its card at more than one size. Keep the grid lines of one size, such as grid.large")
    }

    func testACardOfOtherSpotsRefusesAKeyOfASpotThatRuns() throws {
        try power()
        try widget(more: "# icon=cpu\n# detail=Now\n# keywords=load\n# size=large\n# on=clock.60\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now draws a card of other spots, so it takes no on. Keep title, icon, detail, keywords, size, to and its grid lines, or draw its own blocks with grid lines in its output")
    }

    func testAWidgetThatNamesAMissingMetricIsLeftOutAndReported() throws {
        try widget(grid: ["power none"])

        let scan = try scan

        XCTAssertEqual(scan.spots, [])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Now names no metric called power")])
    }

    func testAWidgetThatOpensAMissingCommandIsLeftOutAndReported() throws {
        try power()
        try widget(more: "# to=nothing\n")

        let scan = try scan

        XCTAssertEqual(scan.spots.map(\.id), ["power"])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Now opens no command called nothing")])
    }

    func testAWidgetOffersEnterOnlyWhenItOpensSomething() {
        let url = URL(fileURLWithPath: "/tmp")
        let still = Spot(id: "a/b", name: "b", url: url, kind: .widget)
        let opening = Spot(id: "a/c", name: "c", url: url, kind: .widget, opens: "a/d")

        XCTAssertNil(still.primaryTitle(hasItem: false))
        XCTAssertEqual(opening.primaryTitle(hasItem: false), "Open")
    }

    func testAWidgetWithAShortcutIsRefusedBecauseThePersonGivesTheLetter() throws {
        try power()
        try widget(more: "# shortcut=w\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots")
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

        let faults = await SpotCheck(folder: SpotFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
    }

    func testTheCheckReportsARefusedHeaderAndABadMetric() async throws {
        try power("echo nonsense")
        try script("broken.sh", "#!/bin/sh\n# size=huge\n")

        let faults = await SpotCheck(folder: SpotFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["broken: Broken has an unknown size: huge", "power: It sent a metric Openspot cannot read."])
    }

    func testTheCheckReportsAListThatFails() async throws {
        try script("tools.sh", "#!/bin/sh\n# on=sheet.open\necho gone >&2\nexit 1\n")

        let faults = await SpotCheck(folder: SpotFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: gone"])
    }

    func testTheCheckFaultsAPartOrAnActionCalledRead() async throws {
        try script("tools.sh", "#!/bin/sh\n# on=sheet.open\nprintf 'button=read\\ntitle=A\\n\\nrow=a\\ntitle=A\\n\\ntext=read\\ntitle=B\\n'\n")

        let faults = await SpotCheck(folder: SpotFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: an action cannot be called read", "tools: a part cannot be called read"])
    }

    func testTheCheckDoesNotRunAScriptWithNoRead() async throws {
        let marker = folder.appendingPathComponent("marker")
        try script("once.sh", "#!/bin/sh\ntouch '\(marker.path)'\n")

        let faults = await SpotCheck(folder: SpotFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
