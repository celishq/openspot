import XCTest
@testable import OpenspotCore

@MainActor
final class SpotEventsTests: SpotRunsCase {
    private final class FakeMac: Mac, @unchecked Sendable {
        var heard: (@MainActor (SpotEvent) -> Void)?
        var count = 0
        private(set) var looks = 0

        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { false }

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

    func testEachOnLineIsOneEventWithAFilterOfItsValue() throws {
        let read = try XCTUnwrap(try SpotRead(on: ["panel.open", "clock.60", "music.track", "clipboard.change", "app.front com\\.apple\\.Notes", "search.text ^[0-9]", "sheet.text"], of: "Clock"))

        XCTAssertEqual(read.moments, [.panel, .every(60), .event("music.track"), .event("clipboard.change"), .event("app.front"), .sheet])
        XCTAssertEqual(read.answers?.text, "^[0-9]")
        XCTAssertTrue(read.searchesSheet)
        XCTAssertTrue(read.admits("app.front", value: "com.apple.Notes"))
        XCTAssertFalse(read.admits("app.front", value: "com.apple.Safari"))
        XCTAssertTrue(read.admits("music.track", value: nil))
        XCTAssertNil(try SpotRead(on: [], of: "Clock"))
    }

    func testALineThatIsNoEventIsAFaultThatNamesIt() {
        func fault(_ line: String) -> String? {
            do {
                _ = try SpotRead(on: [line], of: "Clock")
                return nil
            } catch {
                return (error as? SpotError)?.reason
            }
        }

        XCTAssertEqual(fault("clock.1.5"), "Clock has an unknown clock: clock.1.5. Write a whole number of seconds, such as on=clock.60")
        XCTAssertEqual(fault("search.text"), "Clock needs a pattern of the texts that it answers, such as on=search.text ^[0-9]")
        XCTAssertEqual(fault("app.front ("), "Clock has an unknown filter in on=app.front (. Write a regular expression after the event, such as on=search.text ^[0-9]")
        for line in ["sheet.open x", "panel.open x", "clock.60 x", "sheet.text ^a", "clipboard.change x", "screen.wake x"] {
            let event = line.split(separator: " ")[0]
            XCTAssertEqual(fault(line), "Clock has a filter in on=\(line), and \(event) takes none. Write on=\(event) alone. A filter follows only an event with a value, such as on=app.front com\\.apple\\.Notes")
        }
        for word in ["music", "music.", "clipboard", "60"] {
            XCTAssertEqual(fault(word), "Clock has an unknown event in on=\(word). Write a word with a dot, such as on=sheet.open or on=music.track")
        }
    }

    func testAnEventReadsEachWantedSpotThatListsItWithItsNameAndValue() async throws {
        try script("listens", header: "on=panel.open\non=music.track\noffers=card\noffers=menubar", log: "listens", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        try script("other", header: "on=panel.open\non=other.event\noffers=card\noffers=menubar", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.panelOpened()
        try await wait("the panel reads") { self.log("listens") == ["read"] && self.log("other") == ["read"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read") { self.log("reasons") == ["panel.open none", "music.track Song"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), ["read"])
    }

    func testAnEventWithNoValueGivesNone() async throws {
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        runs.raise(.named("clipboard.change", value: nil))

        try await wait("the event read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testAnEventReadsASpotOnlyWhileSomethingWantsIt() async throws {
        menuBar.insert("wanted")
        try script("wanted", header: "on=music.track\noffers=card\noffers=menubar", log: "wanted", "printf 'text=t\\ntitle=T\\n'")
        try script("unwanted", header: "on=music.track\noffers=card\noffers=menubar", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        try await wait("the first read of the wanted spot") { self.log("wanted") == ["read"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read of the wanted spot") { self.log("wanted") == ["read", "read"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("unwanted"), [])
    }

    func testAnEventForEachSpotReadsAnUnwantedSpotThatListsIt() async throws {
        try script("unwanted", header: "on=app.update\noffers=card\noffers=menubar", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        runs.raise(.named("app.update", value: "2.0", readsEachSpot: true))

        try await wait("the read of the unwanted spot") { self.log("unwanted") == ["read"] }
    }

    func testTheLaunchReadsEachSpotThatListsItWantedOrNot() async throws {
        try script("news", header: "on=app.launch\noffers=card\noffers=menubar", log: "news", "\(reasons)\nprintf 'title=N\\n'")
        try script("other", header: "on=app.update\noffers=card\noffers=menubar", log: "other", "printf 'title=O\\n'")
        _ = try scanned()

        runs.launched()

        try await wait("the launch read") { self.log("reasons") == ["app.launch none"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), [])
    }

    func testASpotThatOffersRowsAndReadsOnlyAsItsSheetOpensReadsAsTheSpotsLoadAndNotAtAPanelOpen() async throws {
        try script("offer", header: "on=sheet.open\noffers=search", log: "offer", "\(reasons)\nprintf 'row=a\\ntitle=A\\n'")
        _ = try scanned()
        try await wait("the rows of the first load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["A"] }
        try script("offer", header: "on=sheet.open\noffers=search", log: "offer", "\(reasons)\nprintf 'row=b\\ntitle=B\\n'")

        runs.panelOpened()
        runs.panelClosed()
        try await allEnded()
        let afterPanel = log("offer")
        _ = try scanned()

        try await wait("the rows of the second load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["B"] }
        XCTAssertEqual(afterPanel, ["read"])
    }

    func testAPanelThatHidesLetsALaunchReadFinish() async throws {
        try script("news", header: "on=app.launch\noffers=card\noffers=menubar", log: "news", "sleep 0.3\necho done >> '\(path("done"))'\nprintf 'title=N\\n'")
        _ = try scanned()

        runs.launched()
        runs.panelOpened()
        runs.panelClosed()

        try await wait("the end of the launch read") { self.exists("done") }
    }

    func testAFailedReadOfAnEventForEachSpotIsTold() async throws {
        try script("unwanted", header: "on=app.update\noffers=card\noffers=menubar", log: "unwanted", "echo 'No news.' >&2\nexit 1")
        let (_, told) = try toldSheet()

        runs.raise(.named("app.update", value: "2.0", readsEachSpot: true))

        try await wait("the failure") { told() == ["No news."] }
    }

    func testASpotThatWaitsForEventsReadsOnceAsItBecomesWanted() async throws {
        try script(header: "on=screen.wake\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try script("other", header: "on=clock.600\noffers=card\noffers=menubar", log: "other", "printf 'text=o\\ntitle=O\\n'")
        menuBar.insert("other")
        _ = try scanned()
        try await wait("the read of the other spot") { self.log("other") == ["read"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("reasons"), [])

        menuBar.insert("script")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }
        _ = try scanned()
        try await allEnded()
        XCTAssertEqual(log("reasons"), ["spot.want none"])
    }

    func testAnEventDuringAReadReadsAgainWithTheNewestEvent() async throws {
        menuBar.insert("script")
        try script(header: "on=music.track\noffers=card\noffers=menubar", "\(reasons)\n[ -z \"$OPENSPOT_VALUE\" ] || \(untilRelease)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "A"))
        try await wait("the read of A") { self.log("reasons").count == 2 }
        runs.raise(.named("music.track", value: "B"))
        runs.raise(.named("music.track", value: "C"))
        openGate()

        try await wait("the read of C") { self.log("reasons") == ["spot.want none", "music.track A", "music.track C"] && !self.runs.isReading }
    }

    func testAStayingScriptGetsTheValueOfItsEvent() {
        XCTAssertEqual(SpotAction.read.block(variables: ReadReason(event: "music.track", value: "Song").variables, id: 3), "call=3\narg=read\nenv.OPENSPOT_REASON=music.track\nenv.OPENSPOT_VALUE=Song\n\n")
        XCTAssertEqual(SpotAction.read.block(variables: ReadReason.panel.variables, id: 3), "call=3\narg=read\nenv.OPENSPOT_REASON=panel.open\n\n")
    }

    func testASpotThatListsAnEventCanShowInTheMenuBar() throws {
        try script(header: "on=app.front\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
        XCTAssertTrue(try sheet().spot.canShowInMenuBar)
    }

    func testTheMacRaisesTheFrontAppAndTheScreenWake() async throws {
        menuBar.insert("script")
        try script(header: "on=app.front\non=screen.wake\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        mac.heard?(.named(SpotEvent.frontApp, value: "com.apple.Safari"))
        try await wait("the front app read") { self.log("reasons") == ["spot.want none", "app.front com.apple.Safari"] && !self.runs.isReading }
        mac.heard?(.named(SpotEvent.screenWake, value: nil))

        try await wait("the screen wake read") { self.log("reasons") == ["spot.want none", "app.front com.apple.Safari", "screen.wake none"] }
    }

    func testTheMacRaisesTheWakeOfTheMac() async throws {
        menuBar.insert("script")
        try script(header: "on=clock.600\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["clock.600 none"] && !self.runs.isReading }

        mac.heard?(.wake)

        try await wait("the wake read") { self.log("reasons") == ["clock.600 none", "clock.600 none"] }
    }

    func testAChangeOfTheClipboardRaisesClipboard() async throws {
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("a look at the clipboard") { self.mac.looks > 1 }
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        mac.count += 1

        try await wait("the clipboard read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testTheClipboardIsWatchedOnlyWhileSomethingWantsASpotThatListsIt() async throws {
        try script("other", header: "on=panel.open", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)
        XCTAssertEqual(mac.looks, 0)

        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
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
        try script(header: "on=panel.open\non=clipboard.change\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)

        runs.panelOpened()
        XCTAssertTrue(runs.watchesClipboard)

        runs.panelClosed()
        XCTAssertFalse(runs.watchesClipboard)
    }

    func testWithThePanelClosedTheClipboardIsLookedAtAfterTwiceItsPause() async throws {
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        let start = Date()

        runs.listen(to: mac)
        try await wait("six looks") { self.mac.looks >= 6 }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.2)
    }

    func testOpeningThePanelLooksAtTheClipboardAtOnce() async throws {
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), clipboardPause: .seconds(4))
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }
        mac.count = 1

        runs.panelOpened()

        try await wait("the clipboard read") { self.log("reasons").contains("clipboard.change none") }
    }

    func testNothingWatchesTheClipboardAfterAQuit() throws {
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        runs.quit()
        _ = try scanned()

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testAQuitEndsTheWatchOfTheClipboard() async throws {
        menuBar.insert("script")
        try script(header: "on=clipboard.change\noffers=card\noffers=menubar", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        let watch = try XCTUnwrap(runs.clipboardWatch)

        runs.quit()
        await watch.value

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testAnEventFromAShellReadsTheSpotThatListsIt() async throws {
        menuBar.insert("script")
        try script(header: "on=music.track\noffers=card\noffers=menubar", "\(reasons)\nprintf 'text=t\\ntitle=%s\\n' \"$OPENSPOT_VALUE\"")
        let sheet = try sheet()
        let config = FileManager.default.temporaryDirectory.appendingPathComponent("oe-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: config) }
        let client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        let runs = runs!
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: CommandAPI(mac: NoHost(), raise: { event in await MainActor.run { runs.raise(event) } })))
        defer { socket.close() }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "\"$0\" event emit music.track 'Blue in Green'", client.path]
        shell.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]

        try shell.run()

        try await wait("the end of the shell") { !shell.isRunning }
        XCTAssertEqual(shell.terminationStatus, 0)
        try await wait("the read of the event") { self.log("reasons") == ["spot.want none", "music.track Blue in Green"] }
        try await wait("the frame of the event") { sheet.reading.value?.title == "Blue in Green" }
    }
}

private final class NoHost: Mac {
    func eventStore() -> any EventStore { FakeEventStore() }
    func reminderStore() -> any ReminderStore { FakeReminderStore() }
    func showCalendar(at time: Date) throws {}
    func open(_ link: URL) -> Bool { false }
}
