import XCTest
@testable import OpenspotCore

/// The rules of events: a spot lists them in its `read`, and each one reads the wanted spots that list it (B1-B5).
@MainActor
final class SpotEventsTests: SpotRunsCase {
    /// A Mac that raises what a test tells it, with a clipboard whose count the test sets.
    private final class FakeMac: EventSource {
        var heard: (@MainActor (SpotEvent) -> Void)?
        var count = 0
        private(set) var looks = 0

        func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void) {
            self.heard = heard
        }

        var clipboardCount: Int {
            looks += 1
            return count
        }
    }

    private var mac = FakeMac()

    override func setUp() async throws {
        try await super.setUp()
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), clipboardPause: .milliseconds(20))
    }

    private var reasons: String {
        "echo \"$OPENSPOT_REASON ${OPENSPOT_VALUE-none}\" >> '\(path("reasons"))'"
    }

    func testAReadTakesEventNamesBesideItsMoments() {
        XCTAssertEqual(SpotRead(text: "panel,music.track,clipboard,app.front,60")?.moments, [.panel, .event("music.track"), .event("clipboard"), .event("app.front"), .every(60)])
        XCTAssertNil(SpotRead(text: "music"))
        XCTAssertNil(SpotRead(text: "1.5"))
        XCTAssertNil(SpotRead(text: "music."))
        XCTAssertNil(SpotRead(text: "music track.x"))
    }

    func testAnEventReadsEachWantedSpotThatListsItWithItsNameAndValue() async throws {
        try script("listens", header: "read=panel,music.track", log: "listens", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        try script("other", header: "read=panel,other.event", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.panelOpened()
        try await wait("the panel reads") { self.log("listens") == ["read"] && self.log("other") == ["read"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read") { self.log("reasons") == ["panel none", "music.track Song"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), ["read"])
    }

    func testAnEventWithNoValueGivesNone() async throws {
        menuBar.insert("script")
        try script(header: "read=clipboard", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }

        runs.raise(.named("clipboard", value: nil))

        try await wait("the event read") { self.log("reasons") == ["timer none", "clipboard none"] }
    }

    func testAnEventReadsASpotOnlyWhileSomethingWantsIt() async throws {
        menuBar.insert("wanted")
        try script("wanted", header: "read=music.track", log: "wanted", "printf 'text=t\\ntitle=T\\n'")
        try script("unwanted", header: "read=music.track", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        try await wait("the first read of the wanted spot") { self.log("wanted") == ["read"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read of the wanted spot") { self.log("wanted") == ["read", "read"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("unwanted"), [])
    }

    func testASpotThatWaitsForEventsReadsOnceAsItBecomesWanted() async throws {
        try script(header: "read=screen.wake", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try script("other", header: "read=600", log: "other", "printf 'text=o\\ntitle=O\\n'")
        menuBar.insert("other")
        _ = try scanned()
        try await wait("the read of the other spot") { self.log("other") == ["read"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("reasons"), [])

        menuBar.insert("script")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }
        _ = try scanned()
        try await allEnded()
        XCTAssertEqual(log("reasons"), ["timer none"])
    }

    func testAnEventDuringAReadReadsAgainWithTheNewestEvent() async throws {
        menuBar.insert("script")
        try script(header: "read=music.track", "\(reasons)\n[ -z \"$OPENSPOT_VALUE\" ] || \(untilRelease)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "A"))
        try await wait("the read of A") { self.log("reasons").count == 2 }
        runs.raise(.named("music.track", value: "B"))
        runs.raise(.named("music.track", value: "C"))
        openGate()

        try await wait("the read of C") { self.log("reasons") == ["timer none", "music.track A", "music.track C"] && !self.runs.isReading }
    }

    func testAStayingScriptGetsTheValueOfItsEvent() {
        XCTAssertEqual(SpotAction.read.event(id: 3, reason: ReadReason(event: "music.track", value: "Song")), "call=3\nreason=music.track\nvalue=Song\narg=read\n\n")
        XCTAssertEqual(SpotAction.read.event(id: 3, reason: .panel), "call=3\nreason=panel\narg=read\n\n")
    }

    func testASpotThatListsAnEventCanShowInTheMenuBar() throws {
        try script(header: "read=app.front", "printf 'text=t\\ntitle=T\\n'")
        XCTAssertTrue(try sheet().command.canShowInMenuBar)
    }

    // MARK: B2, the events of the Mac

    func testTheMacRaisesTheFrontAppAndTheScreenWake() async throws {
        menuBar.insert("script")
        try script(header: "read=app.front,screen.wake", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }

        mac.heard?(.named(SpotEvent.frontApp, value: "com.apple.Safari"))
        try await wait("the front app read") { self.log("reasons") == ["timer none", "app.front com.apple.Safari"] && !self.runs.isReading }
        mac.heard?(.named(SpotEvent.screenWake, value: nil))

        try await wait("the screen wake read") { self.log("reasons") == ["timer none", "app.front com.apple.Safari", "screen.wake none"] }
    }

    func testTheMacRaisesTheWakeOfTheMac() async throws {
        menuBar.insert("script")
        try script(header: "read=600", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }

        mac.heard?(.wake)

        try await wait("the wake read") { self.log("reasons") == ["timer none", "timer none"] }
    }

    func testAChangeOfTheClipboardRaisesClipboard() async throws {
        menuBar.insert("script")
        try script(header: "read=clipboard", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("a look at the clipboard") { self.mac.looks > 1 }
        try await wait("the first read") { self.log("reasons") == ["timer none"] && !self.runs.isReading }

        mac.count += 1

        try await wait("the clipboard read") { self.log("reasons") == ["timer none", "clipboard none"] }
    }

    func testTheClipboardIsWatchedOnlyWhileSomethingWantsASpotThatListsIt() async throws {
        try script("other", header: "read=panel", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)
        XCTAssertEqual(mac.looks, 0)

        try script(header: "read=clipboard", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        XCTAssertFalse(runs.watchesClipboard)

        menuBar.insert("script")
        _ = try scanned()
        XCTAssertTrue(runs.watchesClipboard)

        menuBar = []
        _ = try scanned()
        XCTAssertFalse(runs.watchesClipboard)
    }

    func testTheOpenPanelWantsASpotThatListsThePanelAndTheClipboard() async throws {
        try script(header: "read=panel,clipboard", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)

        runs.panelOpened()
        XCTAssertTrue(runs.watchesClipboard)

        runs.panelClosed()
        XCTAssertFalse(runs.watchesClipboard)
    }

    func testNothingWatchesTheClipboardAfterAQuit() throws {
        menuBar.insert("script")
        try script(header: "read=clipboard", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        runs.quit()
        _ = try scanned()

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testAQuitEndsTheWatchOfTheClipboard() async throws {
        menuBar.insert("script")
        try script(header: "read=clipboard", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        let watch = try XCTUnwrap(runs.clipboardWatch)

        runs.quit()
        await watch.value

        XCTAssertFalse(runs.watchesClipboard)
    }

    // MARK: B3, openspot event emit

    func testAnEventFromAShellReadsTheSpotThatListsIt() async throws {
        menuBar.insert("script")
        try script(header: "read=music.track", "\(reasons)\nprintf 'text=t\\ntitle=%s\\n' \"$OPENSPOT_VALUE\"")
        let sheet = try sheet()
        let config = FileManager.default.temporaryDirectory.appendingPathComponent("oe-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: config) }
        let client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        let runs = runs!
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: CommandAPI(host: NoHost(), raise: { event in await MainActor.run { runs.raise(event) } })))
        defer { socket.close() }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "\"$0\" event emit music.track 'Blue in Green'", client.path]
        shell.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]

        try shell.run()

        try await wait("the end of the shell") { !shell.isRunning }
        XCTAssertEqual(shell.terminationStatus, 0)
        try await wait("the read of the event") { self.log("reasons") == ["timer none", "music.track Blue in Green"] }
        try await wait("the frame of the event") { sheet.reading.value?.title == "Blue in Green" }
    }
}

/// A host of the API that reaches nothing on the Mac.
private struct NoHost: CommandHost {
    func eventStore() -> any EventStore { FakeEventStore() }
    func reminderStore() -> any ReminderStore { FakeReminderStore() }
    func showCalendar(at time: Date) throws {}
    func open(_ link: URL) -> Bool { false }
}
