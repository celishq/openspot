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
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func widgets(_ text: String, file: String = "mine.widget") throws {
        try text.write(to: folder.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    private func power(_ body: String = "printf 'title=84%%\\nvalue=0.84\\ntone=good\\n'") throws {
        try script("power.sh", "#!/bin/sh\n# read=5\n\(body)\n")
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    private func single(size: String?, layout: String = "single", places: Int = 1) throws {
        try power()
        try widgets("name=Now\nlayout=\(layout)\n" + String(repeating: "place=power\n", count: places) + (size.map { "size=\($0)\n" } ?? ""))
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

    func testAReadingKeepsTheNameOfItsMetricBeforeAnyValue() {
        let reading = MetricReading(label: "Battery")
        XCTAssertEqual(reading.label, "Battery")
        XCTAssertNil(reading.value)
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

    func testAWidgetCanPickOneOfItsMetricsForTheMenuBar() throws {
        try power()
        try widgets("name=Level\nlayout=single\nplace=power\ntray=power\n")

        let widget = try XCTUnwrap(try scan.commands.first { $0.kind == .widget })

        XCTAssertEqual(widget.tray, "power")
        XCTAssertEqual(widget.withoutKey().tray, "power")
    }

    func testAWidgetCannotPickAMetricItDoesNotPlace() throws {
        try power()
        try widgets("name=Level\nlayout=single\nplace=power\ntray=other\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Level cannot show other in the menu bar, because it does not place it")
    }

    func testOnlyMenuBarMetricsAreWantedWithThePanelClosed() {
        let url = URL(fileURLWithPath: "/x")
        let metrics = ["a/one", "a/two", "a/three"].map { PluginMetric(id: $0, url: url) }
        let widgets = [
            PluginCommand(id: "a/W", name: "W", url: url, kind: .widget, places: ["a/one", "a/two"], tray: "a/one")
        ]

        XCTAssertEqual(MetricSchedule.wanted(metrics, by: widgets, isPanelOpen: false).map(\.id), ["a/one"])
        XCTAssertEqual(MetricSchedule.wanted(metrics, by: widgets, isPanelOpen: true).map(\.id), ["a/one", "a/two"])
    }

    func testAWidgetFilePlacesMetricsOfOtherScripts() throws {
        try power()
        try widgets("name=Now\nlayout=pair\nplace=power\nplace=power\nkey=w\n\nname=Then\nlayout=single\nplace=power\n")

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
        try widgets("name=Now\nlayout=hero\nplace=power\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now needs 4 places for the hero layout")
    }

    func testAnUnknownLayoutIsRefusedAndNamesTheChoices() throws {
        try widgets("name=Now\nlayout=circle\nplace=power\n")

        XCTAssertEqual(try scan.refused.first?.reason, "Now has an unknown layout: circle. Use single, hero, pair or row")
    }

    func testAWidgetThatNamesAMissingMetricIsLeftOutAndReported() throws {
        try widgets("name=Now\nlayout=pair\nplace=power\nplace=none\n")

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [Refusal(file: "mine", reason: "Now names no metric called power")])
    }

    func testAWidgetThatOpensAMissingCommandIsLeftOutAndReported() throws {
        try power()
        try widgets("name=Now\nlayout=pair\nplace=power\nplace=power\nopens=nothing\n")

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [Refusal(file: "mine", reason: "Now opens no command called nothing")])
    }

    func testAWidgetOffersEnterOnlyWhenItOpensSomething() {
        let url = URL(fileURLWithPath: "/tmp")
        let still = PluginCommand(id: "a/b", name: "b", url: url, kind: .widget)
        let opening = PluginCommand(id: "a/c", name: "c", url: url, kind: .widget, opens: "a/d")

        XCTAssertNil(still.primaryTitle(hasItem: false))
        XCTAssertEqual(opening.primaryTitle(hasItem: false), "Open")
    }

    func testALostKeyKeepsTheRestOfTheCommand() throws {
        try script("one.sh", "#!/bin/sh\n# key=x\n# read=open\n# rank=1\n")
        try script("two.sh", "#!/bin/sh\n# key=x\n# read=open\n# rank=2\n")

        XCTAssertEqual(try scan.commands.map(\.rank), [1, 2])
    }

    func testEveryLayoutFillsItsSizeWithNoOverlap() {
        for layout in WidgetLayout.all {
            var cells = Set<[Int]>()
            for slot in layout.slots {
                for row in slot.row..<(slot.row + slot.rows) {
                    for column in slot.column..<(slot.column + slot.columns) {
                        XCTAssertTrue(cells.insert([row, column]).inserted, layout.name)
                    }
                }
            }
            XCTAssertEqual(cells.count, layout.size.columns * layout.rows, layout.name)
        }
    }

    func testAScheduleGivesEachMetricOnceUntilItsRefreshPasses() {
        let url = URL(fileURLWithPath: "/tmp")
        let fast = PluginMetric(id: "a/fast", url: url, refresh: 5)
        let slow = PluginMetric(id: "a/slow", url: url, refresh: 60)
        let start = Date(timeIntervalSince1970: 1000)
        var schedule = MetricSchedule()

        XCTAssertEqual(schedule.takeDue([fast, slow], now: start).map(\.id), ["a/fast", "a/slow"])
        XCTAssertEqual(schedule.takeDue([fast, slow], now: start.addingTimeInterval(4)).map(\.id), [])
        XCTAssertEqual(schedule.takeDue([fast, slow], now: start.addingTimeInterval(5)).map(\.id), ["a/fast"])
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

    func testTheCheckReportsARefusedHeaderAndABadMetric() async throws {
        try power("echo nonsense")
        try script("broken.sh", "#!/bin/sh\n# size=huge\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["broken: Broken has an unknown size: huge", "power: It sent a metric Openspot cannot read."])
    }

    func testTheCheckReportsAListThatFails() async throws {
        try script("tools.sh", "#!/bin/sh\n# read=click\necho gone >&2\nexit 1\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: gone"])
    }

    func testTheCheckDoesNotRunAScriptWithNoRead() async throws {
        let marker = folder.appendingPathComponent("marker")
        try script("once.sh", "#!/bin/sh\ntouch '\(marker.path)'\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
