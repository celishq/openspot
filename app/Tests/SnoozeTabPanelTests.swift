import XCTest
@testable import OpenspotCore

@MainActor
final class SnoozeTabPanelTests: PanelCase {
    private var repo: URL {
        RepoDoc.repo
    }

    private var tools: URL {
        folder.appendingPathComponent("tools", isDirectory: true)
    }

    override func setUp() async throws {
        try await super.setUp()
        try FileManager.default.copyItem(at: repo.appendingPathComponent("store/snooze-tab.spot"), to: spots.appendingPathComponent("snooze-tab.spot"))
        let app = core.appendingPathComponent("openspot.spot")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: repo.appendingPathComponent("spots/openspot.spot/snooze.js"), to: app.appendingPathComponent("snooze.js"))
        try snoozeManifest().write(to: app.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        for (name, body) in [
            ("lsappinfo", #"case "$*" in *bundleid*) echo '"CFBundleIdentifier"="com.apple.Safari" bundleID="com.apple.Safari"' ;; *name*) echo '"Safari"' ;; *) echo 'ASN:0x0-0x1:' ;; esac"#),
            ("osascript", "case \"$*\" in *'return (URL'*) printf 'https://example.com/a\\nExample page\\n' ;; *close*) echo closed >> '\(folder.path)/closed' ;; esac"),
            ("open", "echo \"$*\" >> '\(folder.path)/opened'")
        ] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: tools.appendingPathComponent("openspot"))
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model.quit()
        let environment = ProcessInfo.processInfo.environment.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new }
        model = SpotsModel(host: host, files: files, runs: SpotRuns(environment: environment, stopPause: stopPause, timers: folder.appendingPathComponent("config/timers.json")))
        host.model = model
        takeCalls()
    }

    private func snoozeManifest() throws -> String {
        let text = try String(contentsOf: repo.appendingPathComponent("spots/openspot.spot/spot.toml"), encoding: .utf8)
        var keeps = false
        return text.components(separatedBy: "\n").filter { line in
            if line.hasPrefix("[") { keeps = line.hasPrefix("[scripts.snooze]") || line.hasPrefix("[scripts.snooze.") }
            return keeps
        }.joined(separator: "\n") + "\n"
    }

    private func timers() async throws -> String {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets["snooze-tab"]?.spot))
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["timer", "list"], folder: folder.path, caller: caller), input: { "" }))
        return await work().output
    }

    func testSnoozeCurrentTabPicksATileOfSnoozeAndAddsATimerThatReopensTheTab() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("snooze-tab")
        try await wait("the sheet of Snooze Tab") { self.model.openSheetID == "snooze-tab" && self.titles.first == "Snooze Current Tab" }

        model.sheets["snooze-tab"]?.list.select(run: "current")
        model.runSelectedItem()
        try await wait("the tiles of Snooze") { self.model.openSheetID == "openspot/snooze" && self.titles.contains("Tomorrow") }
        model.sheets["openspot/snooze"]?.list.select(run: "tomorrow")
        model.runSelectedItem()

        try await wait("the toast after the closed tab") { self.host.confirms.contains("Snoozed the tab.") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("closed").path))
        let list = try await timers()
        XCTAssertTrue(list.contains("input.browser=com.apple.Safari"), list)
        XCTAssertTrue(list.contains("input.url=https://example.com/a"), list)
        XCTAssertTrue(list.contains("input.title=Example page"), list)
    }

    private func snooze(_ id: String, url: String) async throws {
        await model.reload()
        let sheet = try XCTUnwrap(model.sheets["snooze-tab"])
        let value = AttachmentValue(url: url, title: "A page")
        let offer = try XCTUnwrap(sheet.spot.chipActions.first { $0.name == id && $0.fits(value) })
        sheet.run(offer, with: value)
        try await wait("the toast of the snooze") { self.host.confirms.contains { $0.hasPrefix("Snoozed") } }
    }

    private var tomorrowMorning: String {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return ISO8601DateFormatter().string(from: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!)
    }

    func testSnoozeUntilTomorrowClosesTheFrontTabOfItsLinkAndReopensItTomorrowMorning() async throws {
        try await snooze("tomorrow", url: "https://example.com/a")

        XCTAssertEqual(host.confirms.last, "Snoozed the tab.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("closed").path))
        let list = try await timers()
        XCTAssertTrue(list.contains("at=\(tomorrowMorning)"), list)
        XCTAssertTrue(list.contains("input.browser=com.apple.Safari"), list)
        XCTAssertTrue(list.contains("input.url=https://example.com/a"), list)
        XCTAssertTrue(list.contains("input.title=A page"), list)
    }

    func testSnoozeOfALinkThatIsNotTheFrontTabClosesNoTab() async throws {
        try await snooze("week", url: "https://example.com/other")

        XCTAssertEqual(host.confirms.last, "Snoozed the link.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("closed").path))
        let list = try await timers()
        XCTAssertTrue(list.contains("input.url=https://example.com/other"), list)
    }

    func testEachSnoozeActionNamesItsTime() async throws {
        await model.reload()
        let spot = try XCTUnwrap(model.sheets["snooze-tab"]).spot

        XCTAssertEqual(try ["tomorrow", "weekend", "week"].map { try spot.action($0).title }, ["Snooze until tomorrow", "Snooze until the weekend", "Snooze until next week"])
    }
}
