import XCTest
@testable import OpenspotCore

@MainActor
final class ScheduleConsentTests: PanelCase {
    private static let line = "*/5 * * * *"
    private let clock = FakeClock(isReal: true)

    private var scheduleFile: URL {
        folder.appendingPathComponent("config/schedule.json")
    }

    private var calls: URL {
        folder.appendingPathComponent("standup.calls")
    }

    override func setUp() async throws {
        try await super.setUp()
        relaunch()
        try script("standup", toml: "title = 'Stand-up'\n[on]\nschedule = ['\(Self.line)']", "[ \"$1\" = schedule ] && echo \"$1\" >> '\(calls.path)'\nexit 0")
    }

    private func relaunch() {
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: stopPause, schedule: scheduleFile))
        host.model = model
    }

    private var ran: [String] {
        ((try? String(contentsOf: calls, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private var asks: [ToastNote] {
        host.toasts.filter { $0.note.fix == .schedule("standup") }.map(\.note)
    }

    private func passFirstDue() async throws {
        let start = clock.time
        let due = (CronLine(Self.line)?.next(after: start) ?? start).timeIntervalSince(start)
        try await wait("the sleep until the due time") { self.clock.isSleeping(for: due) }
        clock.advance(by: due)
    }

    func testASpotAddedByHandAsksBeforeItsFirstScheduledRunAndRunsAfterAYes() async throws {
        await model.reload()
        try await passFirstDue()

        try await wait("the ask") { self.asks.count == 1 }
        XCTAssertEqual(asks.first?.words, "Stand-up runs by itself on a schedule, so Openspot held its first run. Click to allow it.")
        XCTAssertEqual(ran, [])

        let toast = try XCTUnwrap(model.toasts.queue.first { $0.note.fix == .schedule("standup") })
        model.toasts.press(toast.id)

        try await wait("the run after the yes") { self.ran == ["schedule"] }
    }

    func testAYesIsKeptSoTheNextLaunchRunsWithNoAsk() async throws {
        await model.reload()
        try await passFirstDue()
        try await wait("the ask") { self.asks.count == 1 }
        let toast = try XCTUnwrap(model.toasts.queue.first { $0.note.fix == .schedule("standup") })
        model.toasts.press(toast.id)
        try await wait("the run after the yes") { self.ran == ["schedule"] }

        relaunch()
        await model.reload()
        try await passFirstDue()

        try await wait("the next run") { self.ran == ["schedule", "schedule"] }
        XCTAssertEqual(asks.count, 1)
    }

    func testAnInstalledSpotRunsItsScheduleWithNoAsk() async throws {
        let store = folder.appendingPathComponent("store", isDirectory: true)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: spots.appendingPathComponent("standup.spot"), to: store.appendingPathComponent("standup.spot"))
        _ = try await model.files.lock.add(.folder(store.appendingPathComponent("standup.spot")), to: spots, isConfirmed: true)
        await model.reload()

        try await passFirstDue()

        try await wait("the run") { self.ran == ["schedule"] }
        XCTAssertEqual(asks.count, 0)
    }
}
