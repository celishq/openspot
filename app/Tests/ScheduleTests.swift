import XCTest
@testable import OpenspotCore

@MainActor
final class ScheduleTests: SpotRunsCase {
    private static let line = "*/5 * * * *"

    private var file: URL {
        folder.appendingPathComponent("config/schedule.json")
    }

    override func setUp() async throws {
        try await super.setUp()
        runs = scheduled()
    }

    private func scheduled() -> SpotRuns {
        SpotRuns(clock: clock.value, stopPause: 0.2, schedule: file)
    }

    private func write(_ name: String) throws {
        try script(name, toml: "[on]\nschedule = ['\(Self.line)']", log: name, """
        printf '%s|%s\\n' "$*" "$(grep '^input\\.' | tr '\\n' ' ')" >> '\(path("\(name).calls"))'
        """)
    }

    private func writeEachMode() throws {
        let toml = "[on]\nschedule = ['\(Self.line)']"
        try script("stay", toml: "stay = true\n\(toml)", log: "stay", """
        . "$OPENSPOT_SH"
        main() { printf 'text=a\\ntitle=%s|%s\\n' "$(value cron)" "$(value late)"; }
        openspot_serve main "$@"
        """)
        let url = folder.spotFile("inline", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default {\n  schedule({ cron, late }) { return `text=a\\ntitle=${cron}|${late}\\n` },\n}\n".write(to: url, atomically: true, encoding: .utf8)
        try toml.write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
    }

    private func load() throws -> ScanResult {
        let scan = try KeptScan.shared.load(SpotsFolder(url: folder)).result()
        runs.take(scan)
        return scan
    }

    private func ended(_ name: String) -> Bool {
        runs.sheets[name]?.calls.isEmpty == true
    }

    private var firstDue: TimeInterval {
        let start = clock.time
        let due = CronLine(Self.line)?.next(after: start) ?? start
        return due.timeIntervalSince(start)
    }

    func testADueTimeRunsTheScheduleOnceWithItsLine() async throws {
        try write("script")
        _ = try load()
        let due = firstDue
        try await self.wait("the sleep until the due time") { self.clock.isSleeping(for: due) }

        time += due

        try await self.wait("the run") { self.log("script.calls").count == 1 && self.ended("script") }
        XCTAssertEqual(log("script.calls"), ["schedule|input.cron=\(Self.line) input.late=0 "])
    }

    func testATimeMissedWhileOpenspotWasAwayRunsOnceWithHowLateItIs() async throws {
        try write("script")
        _ = try load()
        let due = firstDue
        runs.quit()

        time += 3600
        runs = scheduled()
        _ = try load()

        try await self.wait("the late run") { self.log("script.calls").count == 1 && self.ended("script") }
        XCTAssertEqual(log("script.calls"), ["schedule|input.cron=\(Self.line) input.late=\(Int(3600 - due)) "])
    }

    func testAReloadThatBrieflyLoadsNoSpotsKeepsTheRecordOfAMissedTime() async throws {
        try write("script")
        _ = try load()
        let due = firstDue
        runs.quit()

        time += 3600
        runs = scheduled()
        runs.take(ScanResult(files: [], refused: []))
        _ = try load()

        try await self.wait("the late run") { self.log("script.calls").count == 1 && self.ended("script") }
        XCTAssertEqual(log("script.calls"), ["schedule|input.cron=\(Self.line) input.late=\(Int(3600 - due)) "])
    }

    func testASpotRemovedBesideAnotherDropsItsRecord() async throws {
        try write("one")
        try write("two")
        _ = try load()

        try FileManager.default.removeItem(at: folder.appendingPathComponent("one.spot"))
        _ = try load()

        let kept = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        XCTAssertEqual(kept.map { Array($0.keys) }, ["two \(Self.line)"])
    }

    func testADueTimeRunsTheScheduleOfAStayingSpotAndOfAnInlineSpot() async throws {
        try writeEachMode()
        var answers: [String: String] = [:]
        runs.onCall = { record in
            guard record.arguments == ["schedule"], record.end == .exited(0) else { return }
            answers[record.spot] = record.frames.joined()
        }
        _ = try load()
        let due = firstDue
        try await self.wait("the sleep until the due time") { self.clock.isSleeping(for: due) }

        time += due

        try await self.wait("the runs") { answers.count == 2 && self.ended("stay") && self.ended("inline") }
        for id in ["stay", "inline"] {
            XCTAssertTrue(answers[id]?.contains("title=\(Self.line)|0\n") == true, "\(id): \(answers[id] ?? "")")
        }
    }
}
