import XCTest
@testable import OpenspotCore

final class MetricContractTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-metrics-\(UUID().uuidString)")
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
