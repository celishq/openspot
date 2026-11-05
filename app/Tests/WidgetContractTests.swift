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

    private func plugin(_ name: String, manifest: String, script: String? = nil) throws {
        let directory = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifest.write(to: directory.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
        if let script {
            let url = directory.appendingPathComponent("run.sh")
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private let power = """
    name = "Power"
    api = 1

    [[metrics]]
    name = "level"
    exec = "run.sh"
    kind = "gauge"
    refresh = 5
    """

    private let powerScript = """
    #!/bin/sh
    [ "$1 $2" = "metric level" ] && printf 'title=84%%\\nvalue=0.84\\ntone=good\\n'
    """

    func testAMetricTakesItsFolderAndName() throws {
        try plugin("power", manifest: power, script: powerScript)

        let metric = try XCTUnwrap(try PluginFolder(url: folder).scan().metrics.first)

        XCTAssertEqual(metric.id, "power/level")
        XCTAssertEqual(metric.kind, .gauge)
        XCTAssertEqual(metric.refresh, 5)
    }

    func testAMetricCanSetATint() throws {
        try plugin("power", manifest: power.replacingOccurrences(of: "kind = \"gauge\"", with: "kind = \"gauge\"\ntint = \"green\""), script: powerScript)

        XCTAssertEqual(try PluginFolder(url: folder).scan().metrics.first?.tint, .green)
    }

    func testAnUnknownTintIsRefusedAndNamesTheChoices() throws {
        try plugin("power", manifest: power.replacingOccurrences(of: "kind = \"gauge\"", with: "kind = \"gauge\"\ntint = \"beige\""), script: powerScript)

        let refused = try XCTUnwrap(try PluginFolder(url: folder).scan().refused.first)

        XCTAssertEqual(refused.reason, "level has an unknown tint: beige. Use red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple or pink")
    }

    private func single(size: String?, layout: String = "single", places: String = "[\"power/level\"]") throws {
        try plugin("power", manifest: power, script: powerScript)
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "\(layout)"
        places = \(places)
        \(size.map { "size = \"\($0)\"" } ?? "")
        """)
    }

    func testASingleWidgetIsSquareUnlessItAsksForAnotherSize() throws {
        try single(size: nil)
        XCTAssertEqual(try PluginFolder(url: folder).scan().commands.first?.size, .square)
    }

    func testASingleWidgetCanAskToBeSmall() throws {
        try single(size: "small")
        XCTAssertEqual(try PluginFolder(url: folder).scan().commands.first?.size, .small)
    }

    func testOnlyASingleWidgetTakesASize() throws {
        try single(size: "small", layout: "pair", places: "[\"power/level\", \"power/level\"]")
        let refused = try XCTUnwrap(try PluginFolder(url: folder).scan().refused.first)
        XCTAssertEqual(refused.reason, "Now cannot take a size, because the pair layout sets its own")
    }

    func testASingleWidgetRefusesAnUnknownSize() throws {
        try single(size: "huge")
        let refused = try XCTUnwrap(try PluginFolder(url: folder).scan().refused.first)
        XCTAssertEqual(refused.reason, "Now has an unknown size: huge")
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

    func testAMetricNamesWhatItMeasures() throws {
        try plugin("power", manifest: power.replacingOccurrences(of: "kind = \"gauge\"", with: "kind = \"gauge\"\nlabel = \"Charge\""), script: powerScript)

        XCTAssertEqual(try PluginFolder(url: folder).scan().metrics.first?.label, "Charge")
    }

    func testAMetricWithNoLabelTakesTheNameOfItsPlugin() throws {
        try plugin("power", manifest: power, script: powerScript)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.metrics.first?.label, scan.plugins.first?.name)
    }

    func testAReadingKeepsTheNameOfItsMetricBeforeAnyValue() {
        let reading = MetricReading(kind: .gauge, label: "Battery")
        XCTAssertEqual(reading.label, "Battery")
        XCTAssertNil(reading.value)
    }

    func testAMetricRefreshesEachMinuteUnlessItSaysOtherwise() throws {
        try plugin("power", manifest: power.replacingOccurrences(of: "refresh = 5\n", with: "").replacingOccurrences(of: "refresh = 5", with: ""), script: powerScript)

        XCTAssertEqual(try PluginFolder(url: folder).scan().metrics.first?.refresh, 60)
    }

    func testAMetricPrintsItsValue() async throws {
        try plugin("power", manifest: power, script: powerScript)
        let metric = try XCTUnwrap(try PluginFolder(url: folder).scan().metrics.first)

        let value = try await metric.read(timeout: 5)

        XCTAssertEqual(value, MetricValue(title: "84%", tone: .good, value: 0.84))
    }

    func testAMetricThatPrintsNonsenseFails() async throws {
        try plugin("power", manifest: power, script: "#!/bin/sh\necho nonsense\n")
        let metric = try XCTUnwrap(try PluginFolder(url: folder).scan().metrics.first)

        do {
            _ = try await metric.read(timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual(error as? PluginError, .badMetric)
        }
    }

    func testAWidgetCanPickOneOfItsMetricsForTheMenuBar() throws {
        try plugin("power", manifest: power + """


        [[widgets]]
        name = "Level"
        layout = "single"
        places = ["power/level"]
        tray = "power/level"
        """, script: powerScript)

        let widget = try XCTUnwrap(try PluginFolder(url: folder).scan().commands.first { $0.kind == .widget })

        XCTAssertEqual(widget.tray, "power/level")
        XCTAssertEqual(widget.withoutKey().tray, "power/level")
    }

    func testAWidgetCannotPickAMetricItDoesNotPlace() throws {
        try plugin("power", manifest: power + """


        [[widgets]]
        name = "Level"
        layout = "single"
        places = ["power/level"]
        tray = "power/other"
        """, script: powerScript)

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.first?.reason, "Level cannot show power/other in the menu bar, because it does not place it")
    }

    func testOnlyMenuBarMetricsAreWantedWithThePanelClosed() {
        let url = URL(fileURLWithPath: "/x")
        let metrics = ["a/one", "a/two", "a/three"].map { PluginMetric(id: $0, name: $0, url: url, kind: .value) }
        let widgets = [
            PluginCommand(id: "a/W", name: "W", url: url, kind: .widget, places: ["a/one", "a/two"], tray: "a/one")
        ]

        XCTAssertEqual(MetricSchedule.wanted(metrics, by: widgets, isPanelOpen: false).map(\.id), ["a/one"])
        XCTAssertEqual(MetricSchedule.wanted(metrics, by: widgets, isPanelOpen: true).map(\.id), ["a/one", "a/two"])
    }

    func testAnUnknownMetricKindIsRefused() throws {
        try plugin("power", manifest: power.replacingOccurrences(of: "gauge", with: "dial"), script: powerScript)

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.first?.file, "power")
    }

    func testAWidgetInAFolderOfItsOwnPlacesMetricsOfAnotherPlugin() throws {
        try plugin("power", manifest: power, script: powerScript)
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "pair"
        places = ["power/level", "power/level"]
        key = "w"
        """)

        let scan = try PluginFolder(url: folder).scan()
        let widget = try XCTUnwrap(scan.commands.first)

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(widget.id, "mine/Now")
        XCTAssertEqual(widget.kind, .widget)
        XCTAssertEqual(widget.size, .strip)
        XCTAssertEqual(widget.layout, .pair)
        XCTAssertEqual(widget.places, ["power/level", "power/level"])
        XCTAssertEqual(widget.key?.name, "w")
    }

    func testAWidgetNeedsOnePlaceForEachSlot() throws {
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "hero"
        places = ["power/level"]
        """)

        let refused = try XCTUnwrap(try PluginFolder(url: folder).scan().refused.first)

        XCTAssertEqual(refused.reason, "Now needs 4 places for the hero layout")
    }

    func testAnUnknownLayoutIsRefusedAndNamesTheChoices() throws {
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "circle"
        places = ["power/level"]
        """)

        let refused = try XCTUnwrap(try PluginFolder(url: folder).scan().refused.first)

        XCTAssertEqual(refused.reason, "Now has an unknown layout: circle. Use single, hero, pair or row")
    }

    func testAWidgetThatNamesAMissingMetricIsLeftOutAndReported() throws {
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "pair"
        places = ["power/level", "power/none"]
        """)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [Refusal(file: "mine", reason: "Now names no metric called power/level")])
    }

    func testAWidgetThatOpensAMissingCommandIsLeftOutAndReported() throws {
        try plugin("power", manifest: power, script: powerScript)
        try plugin("mine", manifest: """
        name = "Mine"
        api = 1

        [[widgets]]
        name = "Now"
        layout = "pair"
        places = ["power/level", "power/level"]
        opens = "power/Nothing"
        """)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.refused, [Refusal(file: "mine", reason: "Now opens no command called power/Nothing")])
    }

    func testACommandCannotCallItselfAWidget() throws {
        try plugin("power", manifest: """
        name = "Power"
        api = 1

        [[commands]]
        name = "Now"
        exec = "run.sh"
        type = "widget"
        """, script: "#!/bin/sh\n")

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.first?.reason, "Now has an unknown type: widget")
    }

    func testAWidgetOffersEnterOnlyWhenItOpensSomething() {
        let url = URL(fileURLWithPath: "/tmp")
        let still = PluginCommand(id: "a/b", name: "b", url: url, kind: .widget)
        let opening = PluginCommand(id: "a/c", name: "c", url: url, kind: .widget, opens: "a/d")

        XCTAssertNil(still.primaryTitle(hasItem: false))
        XCTAssertEqual(opening.primaryTitle(hasItem: false), "Open")
    }

    func testALostKeyKeepsTheRestOfTheCommand() throws {
        try plugin("one", manifest: """
        name = "One"
        api = 1

        [[commands]]
        name = "First"
        exec = "run.sh"
        key = "x"
        rank = 1
        """, script: "#!/bin/sh\n")
        try plugin("two", manifest: """
        name = "Two"
        api = 1

        [[commands]]
        name = "Second"
        exec = "run.sh"
        key = "x"
        rank = 2
        """, script: "#!/bin/sh\n")

        XCTAssertEqual(try PluginFolder(url: folder).scan().commands.map(\.rank), [1, 2])
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
        let fast = PluginMetric(id: "a/fast", name: "fast", url: url, kind: .value, refresh: 5)
        let slow = PluginMetric(id: "a/slow", name: "slow", url: url, kind: .value, refresh: 60)
        let start = Date(timeIntervalSince1970: 1000)
        var schedule = MetricSchedule()

        XCTAssertEqual(schedule.takeDue([fast, slow], now: start).map(\.id), ["a/fast", "a/slow"])
        XCTAssertEqual(schedule.takeDue([fast, slow], now: start.addingTimeInterval(4)).map(\.id), [])
        XCTAssertEqual(schedule.takeDue([fast, slow], now: start.addingTimeInterval(5)).map(\.id), ["a/fast"])
    }

    func testAFailedReadKeepsTheLastValueAndMarksItStale() {
        var reading = MetricReading(kind: .value, label: "Cups")
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
        try plugin("power", manifest: power, script: powerScript)

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
    }

    func testTheCheckReportsARefusedManifestAndABadMetric() async throws {
        try plugin("power", manifest: power, script: "#!/bin/sh\necho nonsense\n")
        try plugin("broken", manifest: "name = \"Broken\"\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["broken: needs an api", "power/level: It sent a metric Openspot cannot read."])
    }

    func testTheCheckReportsAListThatFails() async throws {
        try plugin("tools", manifest: """
        name = "Tools"
        api = 1

        [[commands]]
        name = "List"
        exec = "run.sh"
        type = "list"
        """, script: "#!/bin/sh\necho gone >&2\nexit 1\n")

        let faults = await PluginCheck(folder: PluginFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools/List: gone"])
    }
}
