import XCTest
@testable import OpenspotCore

@MainActor
final class MetricSpotsTests: SpotRunsCase {
    private final class FakeMac: MacEvents, @unchecked Sendable {
        var sample = LoadSample(busy: 0, total: 0, memory: 0)

        func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {}

        var clipboardCount: Int {
            0
        }

        func measureLoad() -> LoadSample {
            sample
        }
    }

    private let mac = FakeMac()
    private let fake = FakeClock()
    private let metrics = ["battery", "cpu", "devices", "disk", "memory"]

    private var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
    }

    override func setUp() async throws {
        try await super.setUp()
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        let tool = { (name: String, answer: String) in
            try "#!/bin/sh\necho \(name) >> '\(self.path("tools.log"))'\nprintf '%s\\n' '\(answer)'\n".writeScript(to: tools.appendingPathComponent(name))
        }
        try tool("pmset", " -InternalBattery-0 (id=1)\t84%; discharging; 3:12 remaining present: true")
        try tool("df", "Filesystem 1024-blocks Used Available\n/dev/disk3s5 1000000 400000 600000")
        try tool("system_profiler", "")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = tools.path + ":/usr/bin:/bin"
        environment["OPENSPOT_CONFIG"] = folder.appendingPathComponent("config").path
        runs = SpotRuns(environment: environment, clock: fake.value, stopPause: 0.2)
        for name in metrics { try copy(name) }
    }

    private func copy(_ name: String) throws {
        let source = repoSpots.appendingPathComponent("\(name).spot/\(name).sh")
        let lines = try String(contentsOf: source, encoding: .utf8).components(separatedBy: "\n")
        let header = lines.dropFirst().prefix { $0.hasPrefix("#") }.count + 1
        let body = lines.prefix(header) + ["echo $$ >> '\(path("pids"))'"] + lines.dropFirst(header)
        let toml = try String(contentsOf: source.deletingLastPathComponent().appendingPathComponent(SpotToml.fileName), encoding: .utf8)
        try body.joined(separator: "\n").writeScript(to: folder.appendingPathComponent("\(name).spot/\(name).sh"), toml: toml)
    }

    private func title(_ id: String) -> String? {
        runs.sheets[id]?.reading.value?.title
    }

    func testEachMetricReadsAnEventOfTheMacAndNoClock() throws {
        let scan = try scanned()

        for id in metrics {
            let read = try XCTUnwrap(scan.spots.first { $0.id == id }?.read, id)
            XCTAssertNil(read.seconds, id)
        }
    }

    func testAMetricInTheMenuBarStartsNoProcessForAMinuteWhileNothingChanges() async throws {
        menuBar = Set(metrics)
        runs.listen(to: mac)
        mac.sample = LoadSample(busy: 10, total: 100, memory: 40)
        _ = try scanned()
        try await wait("the first reads") { self.title("battery") == "84%" && self.title("disk") == "40%" && self.runs.watchesLoad && !self.runs.isReading }
        let started = log("pids").count
        let tools = log("tools.log")
        XCTAssertEqual(started, metrics.count)

        for step in 1...12 {
            mac.sample = LoadSample(busy: UInt64(10 + step * 2), total: UInt64(100 + step * 10), memory: 40 + step)
            try await wait("the sleep of the load") { self.fake.isSleeping(for: 5) }
            fake.advance(by: 5)
            try await wait("the load of step \(step)") { self.title("memory") == "\(40 + step)%" && self.title("cpu") == "20%" && !self.runs.isReading }
        }

        XCTAssertEqual(log("pids").count, started)
        XCTAssertEqual(log("tools.log"), tools)
        XCTAssertEqual(runs.sheets["cpu"]?.reading.value?.points?.count, 12)
    }

    func testCPUAndMemoryShowAValueOnAReadWithNoLoad() async throws {
        menuBar = ["cpu", "memory"]

        _ = try scanned()

        try await wait("the first reads") { self.title("cpu")?.hasSuffix("%") == true && self.title("memory")?.hasSuffix("%") == true }
    }

    func testTheBatteryReadsAgainWhenThePowerSourceChanges() async throws {
        menuBar = ["battery"]
        runs.listen(to: mac)
        _ = try scanned()
        try await wait("the first read") { self.title("battery") == "84%" && !self.runs.isReading }
        fake.advance(by: 60)
        XCTAssertEqual(log("tools.log"), ["pmset"])

        runs.raise(.named(SpotEvent.powerChange, value: "ac"))

        try await wait("the read of the change") { self.log("tools.log") == ["pmset", "pmset"] && !self.runs.isReading }
    }

    func testTheDevicesAskTheBluetoothReportOnceInFiveMinutesUnlessADeviceConnects() async throws {
        menuBar = ["devices"]
        runs.listen(to: mac)
        _ = try scanned()
        try await wait("the first read") { self.title("devices") == "–" && !self.runs.isReading }
        let script = folder.appendingPathComponent("devices.spot/devices.sh")
        var kept = ""

        for try await frame in ScriptProcess(url: script, arguments: ["show"], mode: .once(input: "event=spot.want\n"), limit: 60, dataName: "devices", base: runs.environment).start() { kept += frame }
        XCTAssertEqual(log("tools.log"), ["system_profiler"])
        XCTAssertTrue(kept.contains("title=–"), kept)

        runs.raise(.named(SpotEvent.deviceConnect, value: "Keyboard"))

        try await wait("the read of the device") { self.log("tools.log") == ["system_profiler", "system_profiler"] && !self.runs.isReading }
    }

    func testSystemDrawsItsOwnCardOfTheBatteryTheCPUTheMemoryAndTheDevicesAtTheirEvents() async throws {
        try copy("system")
        runs.listen(to: mac)
        mac.sample = LoadSample(busy: 10, total: 100, memory: 40)
        let scan = try scanned()
        runs.take(grid: ["system"])
        runs.panelOpened()
        let titles = { Dictionary((self.runs.sheets["system"]?.state.face.parts ?? []).map { ($0.id, $0.title ?? "") }) { first, _ in first } }
        XCTAssertNil(try XCTUnwrap(scan.spots.first { $0.id == "system" }?.read).seconds)
        try await wait("the first read") { titles()["battery"] == "84%" && titles()["devices"] == "–" && titles()["memory"] != nil && !self.runs.isReading }

        mac.sample = LoadSample(busy: 30, total: 200, memory: 55)
        try await wait("the sleep of the load") { self.fake.isSleeping(for: 5) }
        fake.advance(by: 5)
        try await wait("the load") { titles()["memory"] == "55%" && titles()["cpu"] == "20%" && !self.runs.isReading }
        runs.raise(.named(SpotEvent.powerChange, value: "ac"))
        try await wait("the read of the power") { self.log("tools.log").filter { $0 == "pmset" }.count == 2 && !self.runs.isReading }
        runs.raise(.named(SpotEvent.deviceConnect, value: "Keyboard"))
        try await wait("the read of the device") { self.log("tools.log").filter { $0 == "system_profiler" }.count == 2 && !self.runs.isReading }
    }
}
