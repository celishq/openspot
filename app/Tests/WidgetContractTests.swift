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

    private func script(_ name: String, _ text: String, toml: String = "") throws {
        let url = folder.appendingPathComponent(name.inSpotFolder)
        try text.writeScript(to: url, toml: toml)
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: url.path)
    }

    private func power(_ body: String = "printf 'graph=power\\ntitle=84%%\\nvalue=0.84\\ntone=good\\n'") throws {
        try script("power.sh", "#!/bin/sh\n\(body)\n", toml: "on = ['clock.5']")
    }

    private var scan: ScanResult {
        get throws { try SpotsFolder(url: folder).scan() }
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

    func testAOneLineDrawingIsAStrip() {
        XCTAssertEqual(WidgetLayout(drawing: ["a b c"]).size, .strip)
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

        let value = try await metric.read(timeout: 60)

        XCTAssertEqual(value, MetricValue(title: "84%", tone: .good, value: 0.84))
    }

    func testAMetricThatPrintsNonsenseFails() async throws {
        try power("echo nonsense")
        let metric = try XCTUnwrap(try scan.metrics.first)

        do {
            _ = try await metric.read(timeout: 60)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual(error as? SpotError, .badMetric)
        }
    }

    func testEachSpotCanShowInTheMenuBar() throws {
        try script("one.sh", "#!/bin/sh\n")
        try script("two.sh", "#!/bin/sh\n", toml: "on = ['panel.open']")
        try script("three.sh", "#!/bin/sh\n", toml: "mode = 'stay'")
        try script("four.sh", "#!/bin/sh\n", toml: "on = ['clock.5']")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.scripts.filter(\.canShowInMenuBar).map(\.id), ["four", "one", "three", "two"])
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

        let faults = await SpotCheck(folder: SpotsFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
    }

    func testTheCheckReportsARefusedHeaderAndABadMetric() async throws {
        try power("echo nonsense")
        try script("broken.sh", "#!/bin/sh\n", toml: "mode = 'huge'")

        let faults = await SpotCheck(folder: SpotsFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["broken: Broken has an unknown mode: huge. Use once or stay", "power: It sent a metric Openspot cannot read."])
    }

    func testTheCheckReportsAListThatFails() async throws {
        try script("tools.sh", "#!/bin/sh\necho gone >&2\nexit 1\n", toml: "on = ['sheet.open']")

        let faults = await SpotCheck(folder: SpotsFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: gone"])
    }

    func testTheCheckFaultsAPartOrAnActionCalledShow() async throws {
        try script("tools.sh", "#!/bin/sh\nprintf 'button=show\\ntitle=A\\n\\ntext=a\\ntitle=A\\n\\ntext=show\\ntitle=B\\n'\n", toml: "on = ['sheet.open']")

        let faults = await SpotCheck(folder: SpotsFolder(url: folder)).faults()

        XCTAssertEqual(faults, ["tools: an action cannot be called show", "tools: an item cannot be called show"])
    }

    func testTheCheckDoesNotRunAScriptWithNoRead() async throws {
        let marker = folder.appendingPathComponent("marker")
        try script("once.sh", "#!/bin/sh\ntouch '\(marker.path)'\n")

        let faults = await SpotCheck(folder: SpotsFolder(url: folder)).faults()

        XCTAssertEqual(faults, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
