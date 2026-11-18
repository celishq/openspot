import XCTest
@testable import OpenspotCore

@MainActor
final class SpotEventsTests: SpotRunsCase {
    private final class FakeMac: MacEvents, @unchecked Sendable {
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

        var sample = LoadSample(busy: 0, total: 0, memory: 0)
        private(set) var samples = 0

        func measureLoad() -> LoadSample {
            samples += 1
            return sample
        }
    }

    private var mac = FakeMac()

    override func setUp() async throws {
        try await super.setUp()
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, clipboardPause: .milliseconds(20))
    }

    private var reasons: String {
        "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("reasons"))'"
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
        try script("listens", toml: "on = ['panel.open', 'music.track']", log: "listens", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        try script("other", toml: "on = ['panel.open', 'other.event']", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.panelOpened()
        try await wait("the panel reads") { self.log("listens") == ["show"] && self.log("other") == ["show"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read") { self.log("reasons") == ["panel.open none", "music.track Song"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), ["show"])
    }

    func testAnEventWithNoValueGivesNone() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['clipboard.change']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        runs.raise(.named("clipboard.change", value: nil))

        try await wait("the event read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testAnEventReadsASpotOnlyWhileSomethingWantsIt() async throws {
        menuBar.insert("wanted")
        try script("wanted", toml: "on = ['music.track']", log: "wanted", "printf 'text=t\\ntitle=T\\n'")
        try script("unwanted", toml: "on = ['music.track']", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        try await wait("the first read of the wanted spot") { self.log("wanted") == ["show"] && !self.runs.isReading }

        runs.raise(.named("music.track", value: "Song"))

        try await wait("the event read of the wanted spot") { self.log("wanted") == ["show", "show"] && !self.runs.isReading }
        try await allEnded()
        XCTAssertEqual(log("unwanted"), [])
    }

    func testAnEventForEachSpotReadsAnUnwantedSpotThatListsIt() async throws {
        try script("unwanted", toml: "on = ['app.update']", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        runs.raise(.named("app.update", value: "2.0", readsEachSpot: true))

        try await wait("the read of the unwanted spot") { self.log("unwanted") == ["show"] }
    }

    func testTheLaunchReadsEachSpotThatListsItWantedOrNot() async throws {
        try script("news", toml: "on = ['app.launch']", log: "news", "\(reasons)\nprintf 'frame=\\ntitle=N\\n'")
        try script("other", toml: "on = ['app.update']", log: "other", "printf 'frame=\\ntitle=O\\n'")
        _ = try scanned()

        runs.launched()

        try await wait("the launch read") { self.log("reasons") == ["app.launch none"] && !self.runs.isReading }
        XCTAssertEqual(log("other"), [])
    }

    func testASpotThatOffersRowsAndReadsOnlyAsItsSheetOpensReadsAsTheSpotsLoadAndNotAtAPanelOpen() async throws {
        try script("offer", toml: "on = ['sheet.open']\noffers = ['search']", log: "offer", "\(reasons)\nprintf 'text=a\\ntitle=A\\n'")
        _ = try scanned()
        try await wait("the rows of the first load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["A"] }
        try script("offer", toml: "on = ['sheet.open']\noffers = ['search']", log: "offer", "\(reasons)\nprintf 'text=b\\ntitle=B\\n'")

        runs.panelOpened()
        runs.panelClosed()
        try await allEnded()
        let afterPanel = log("offer")
        _ = try scanned()

        try await wait("the rows of the second load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["B"] }
        XCTAssertEqual(afterPanel, ["show"])
    }

    func testAPanelThatHidesLetsALaunchReadFinish() async throws {
        try script("news", toml: "on = ['app.launch']", log: "news", "sleep 0.3\necho done >> '\(path("done"))'\nprintf 'frame=\\ntitle=N\\n'")
        _ = try scanned()

        runs.launched()
        runs.panelOpened()
        runs.panelClosed()

        try await wait("the end of the launch read") { self.exists("done") }
    }

    func testAFailedReadOfAnEventForEachSpotIsTold() async throws {
        try script("unwanted", toml: "on = ['app.update']", log: "unwanted", "echo 'No news.' >&2\nexit 1")
        let (_, told) = try toldSheet()

        runs.raise(.named("app.update", value: "2.0", readsEachSpot: true))

        try await wait("the failure") { told() == ["No news."] }
    }

    func testASpotThatWaitsForEventsReadsOnceAsItBecomesWanted() async throws {
        try script(toml: "on = ['screen.wake']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try script("other", toml: "on = ['clock.600']", log: "other", "printf 'text=o\\ntitle=O\\n'")
        menuBar.insert("other")
        _ = try scanned()
        try await wait("the read of the other spot") { self.log("other") == ["show"] && !self.runs.isReading }
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
        try script(toml: "on = ['music.track']", "\(reasons)\n[ -z \"$val\" ] || \(untilRelease)\nprintf 'text=t\\ntitle=T\\n'")
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
        XCTAssertEqual(SpotAction.show.block(input: TextBlock(fields: ReadReason(event: "music.track", value: "Song").fields).text, id: 3), "call=3\narg=show\nevent=music.track\nevent.value=Song\n\n")
        XCTAssertEqual(SpotAction.show.block(input: TextBlock(fields: ReadReason.panel.fields).text, id: 3), "call=3\narg=show\nevent=panel.open\n\n")
    }

    func testASpotThatListsAnEventCanShowInTheMenuBar() throws {
        try script(toml: "on = ['app.front']", "printf 'text=t\\ntitle=T\\n'")
        XCTAssertTrue(try sheet().spot.canShowInMenuBar)
    }

    func testTheMacRaisesTheFrontAppAndTheScreenWake() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['app.front', 'screen.wake']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
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
        try script(toml: "on = ['clock.600']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["clock.600 none"] && !self.runs.isReading }

        mac.heard?(.wake)

        try await wait("the wake read") { self.log("reasons") == ["clock.600 none", "clock.600 none"] }
    }

    func testAChangeOfTheClipboardRaisesClipboard() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['clipboard.change']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("a look at the clipboard") { self.mac.looks > 1 }
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }

        mac.count += 1

        try await wait("the clipboard read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testTheClipboardIsWatchedOnlyWhileSomethingWantsASpotThatListsIt() async throws {
        try script("other", toml: "on = ['panel.open']", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)
        XCTAssertEqual(mac.looks, 0)

        try script(toml: "on = ['clipboard.change']", "printf 'text=t\\ntitle=T\\n'")
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
        try script(toml: "on = ['panel.open', 'clipboard.change']", "printf 'text=t\\ntitle=T\\n'")
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
        try script(toml: "on = ['clipboard.change']", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        let start = Date()

        runs.listen(to: mac)
        try await wait("six looks") { self.mac.looks >= 6 }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.2)
    }

    func testOpeningThePanelLooksAtTheClipboardAtOnce() async throws {
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, clipboardPause: .seconds(4))
        menuBar.insert("script")
        try script(toml: "on = ['clipboard.change']", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }
        mac.count = 1

        runs.panelOpened()

        try await wait("the clipboard read") { self.log("reasons").contains("clipboard.change none") }
    }

    func testNothingWatchesTheClipboardAfterAQuit() throws {
        menuBar.insert("script")
        try script(toml: "on = ['clipboard.change']", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        runs.quit()
        _ = try scanned()

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testAQuitEndsTheWatchOfTheClipboard() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['clipboard.change']", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        let watch = try XCTUnwrap(runs.clipboardWatch)

        runs.quit()
        await watch.value

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testOneSampleOfTheLoadServesEachWantedReaderAndNoneIsTakenWithNoReader() async throws {
        let fake = FakeClock()
        runs = SpotRuns(clock: fake.value, stopPause: 0.2)
        try script("one", toml: "on = ['system.load']", log: "one", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("one-reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        try script("two", toml: "on = ['system.load cpu=[0-9]+']", log: "two", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("two-reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        fake.advance(by: 60)
        XCTAssertFalse(runs.watchesLoad)
        XCTAssertEqual(mac.samples, 0)

        menuBar = ["one", "two"]
        _ = try scanned()
        XCTAssertTrue(runs.watchesLoad)
        XCTAssertEqual(mac.samples, 1)
        try await wait("the first reads") { self.log("one-reasons") == ["spot.want none"] && self.log("two-reasons") == ["spot.want none"] && !self.runs.isReading }
        try await wait("the sleep of the watch") { fake.isSleeping(for: 5) }
        mac.sample = LoadSample(busy: 30, total: 100, memory: 61)

        fake.advance(by: 5)

        try await wait("the load reads") { self.log("one-reasons").last == "system.load cpu=30 memory=61" && self.log("two-reasons").last == "system.load cpu=30 memory=61" }
        XCTAssertEqual(mac.samples, 2)

        menuBar = []
        _ = try scanned()
        XCTAssertFalse(runs.watchesLoad)
        fake.advance(by: 60)
        try await allEnded()
        XCTAssertEqual(mac.samples, 2)
    }

    func testAReaderThatComesBackWithin10SecondsGetsTheLoadAtOnceAndOneLaterWaitsForTwoSamples() async throws {
        let fake = FakeClock()
        runs = SpotRuns(clock: fake.value, stopPause: 0.2)
        try script("one", toml: "on = ['system.load']", log: "one", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        runs.listen(to: mac)
        menuBar = ["one"]
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isReading }
        menuBar = []
        _ = try scanned()
        fake.advance(by: 3)
        mac.sample = LoadSample(busy: 20, total: 100, memory: 40)

        menuBar = ["one"]
        _ = try scanned()

        try await wait("the load at once") { self.log("reasons").contains("system.load cpu=20 memory=40") && !self.runs.isReading }
        menuBar = []
        _ = try scanned()
        fake.advance(by: 11)
        mac.sample = LoadSample(busy: 50, total: 200, memory: 40)
        menuBar = ["one"]
        _ = try scanned()
        try await wait("the watch") { self.runs.watchesLoad && fake.isSleeping(for: 5) && !self.runs.isReading }
        try await allEnded()

        XCTAssertEqual(log("reasons").filter { $0.hasPrefix("system.load") }, ["system.load cpu=20 memory=40"])
    }

    func testTheEventsOfTheMacThatCarryAValueTakeAFilter() throws {
        for line in ["power.change battery", "disk.mount ^/Volumes/", "device.connect Keyboard", "system.load cpu=9[0-9]"] {
            XCTAssertNotNil(try SpotRead(on: [line], of: "Probe"))
        }
    }

    func testAnEventFromAShellReadsTheSpotThatListsIt() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['music.track']", "\(reasons)\nprintf 'text=t\\ntitle=%s\\n' \"$val\"")
        let sheet = try sheet()
        let config = FileManager.default.temporaryDirectory.appendingPathComponent("oe-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: config) }
        let client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        let runs = runs!
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), raise: { event in await MainActor.run { runs.raise(event) } }, rates: .offline)))
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
