import XCTest
@testable import OpenspotCore

@MainActor
final class SpotEventsTests: SpotRunsCase {
    private final class FakeMac: MacEvents, @unchecked Sendable {
        var heard: (@MainActor (AppSignal) -> Void)?
        var count = 0
        private(set) var looks = 0

        func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
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

    func testAnEventReadsEachWantedSpotThatListsItWithItsNameAndValue() async throws {
        try script("listens", toml: "[on]\n\"panel.open\" = true\n\"power.change\" = true", log: "listens", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        try script("other", toml: "[on]\n\"panel.open\" = true\n\"disk.mount\" = true", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.panelOpened()
        try await wait("the panel reads") { self.log("listens") == ["show"] && self.log("other") == ["show"] && !self.runs.isShowing }

        runs.raise(.named(EventName.powerChange, value: "Song"))

        try await wait("the event read") { self.log("reasons") == ["panel.open none", "power.change Song"] && !self.runs.isShowing }
        XCTAssertEqual(log("other"), ["show"])
    }

    func testAnEventWithNoValueGivesNone() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }

        runs.raise(.named("clipboard.change", value: nil))

        try await wait("the event read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testAnEventReadsASpotOnlyWhileSomethingWantsIt() async throws {
        menuBar.insert("wanted")
        try script("wanted", toml: "[on]\n\"power.change\" = true", log: "wanted", "printf 'text=t\\ntitle=T\\n'")
        try script("unwanted", toml: "[on]\n\"power.change\" = true", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        try await wait("the first read of the wanted spot") { self.log("wanted") == ["show"] && !self.runs.isShowing }

        runs.raise(.named(EventName.powerChange, value: "Song"))

        try await wait("the event read of the wanted spot") { self.log("wanted") == ["show", "power.change"] && !self.runs.isShowing }
        try await allEnded()
        XCTAssertEqual(log("unwanted"), [])
    }

    func testAnEventForEachSpotReadsAnUnwantedSpotThatListsIt() async throws {
        try script("unwanted", toml: "[on]\n\"app.update\" = true", log: "unwanted", "printf 'text=u\\ntitle=U\\n'")
        _ = try scanned()

        runs.raise(.named("app.update", value: "2.0", showsEachSpot: true))

        try await wait("the read of the unwanted spot") { self.log("unwanted") == ["app.update"] }
    }

    func testTheLaunchReadsEachSpotThatListsItWantedOrNot() async throws {
        try script("news", toml: "[on]\n\"app.launch\" = true", log: "news", "\(reasons)\nprintf 'frame=\\ntitle=N\\n'")
        try script("other", toml: "[on]\n\"app.update\" = true", log: "other", "printf 'frame=\\ntitle=O\\n'")
        _ = try scanned()

        runs.launched()

        try await wait("the launch read") { self.log("reasons") == ["app.launch none"] && !self.runs.isShowing }
        XCTAssertEqual(log("other"), [])
    }

    func testASpotThatOffersRowsWithNoReadingEventReadsAsTheSpotsLoadAndNotAtAPanelOpen() async throws {
        try script("offer", toml: "[on]\nsearch = true", log: "offer", "\(reasons)\nprintf 'item=a\\ntitle=A\\n'")
        _ = try scanned()
        try await wait("the rows of the first load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["A"] }
        try script("offer", toml: "[on]\nsearch = true", log: "offer", "\(reasons)\nprintf 'item=b\\ntitle=B\\n'")

        runs.panelOpened()
        runs.panelClosed()
        try await allEnded()
        let afterPanel = log("offer")
        _ = try scanned()

        try await wait("the rows of the second load") { self.runs.sheets["offer"]?.list.all.map(\.title) == ["B"] }
        XCTAssertEqual(afterPanel, ["show"])
    }

    func testAPanelThatHidesLetsALaunchReadFinish() async throws {
        try script("news", toml: "[on]\n\"app.launch\" = true", log: "news", "sleep 0.3\necho done >> '\(path("done"))'\nprintf 'frame=\\ntitle=N\\n'")
        _ = try scanned()

        runs.launched()
        runs.panelOpened()
        runs.panelClosed()

        try await wait("the end of the launch read") { self.placed(at: path("done")) }
    }

    func testAFailedReadOfAnEventForEachSpotIsTold() async throws {
        try script("unwanted", toml: "[on]\n\"app.update\" = true", log: "unwanted", "echo 'No news.' >&2\nexit 1")
        let (_, told) = try toldSheet()

        runs.raise(.named("app.update", value: "2.0", showsEachSpot: true))

        try await wait("the failure") { told() == ["No news."] }
    }

    func testASpotThatWaitsForEventsReadsOnceAsItBecomesWanted() async throws {
        try script(toml: "[on]\n\"screen.wake\" = true", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try script("other", toml: "[on]\nevery = 600", log: "other", "printf 'text=o\\ntitle=O\\n'")
        menuBar.insert("other")
        _ = try scanned()
        try await wait("the read of the other spot") { self.log("other") == ["every"] && !self.runs.isShowing }
        try await allEnded()
        XCTAssertEqual(log("reasons"), [])

        menuBar.insert("script")
        _ = try scanned()

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }
        _ = try scanned()
        try await allEnded()
        XCTAssertEqual(log("reasons"), ["spot.want none"])
    }

    func testAnEventDuringAReadReadsAgainWithTheNewestEvent() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"power.change\" = true", "\(reasons)\n[ -z \"$val\" ] || \(untilRelease)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }

        runs.raise(.named(EventName.powerChange, value: "A"))
        try await wait("the read of A") { self.log("reasons").count == 2 }
        runs.raise(.named(EventName.powerChange, value: "B"))
        runs.raise(.named(EventName.powerChange, value: "C"))
        openGate()

        try await wait("the read of C") { self.log("reasons") == ["spot.want none", "power.change A", "power.change C"] && !self.runs.isShowing }
    }

    func testAStayingScriptGetsTheValueOfItsEvent() {
        XCTAssertEqual(ShowEvent.event(EventName.powerChange, value: "ac").message().block(id: 3), "call=3\narg=power.change\ninput.value=ac\n\n")
        XCTAssertEqual(ShowEvent.panel.message().block(id: 3), "call=3\narg=show\ninput.event=panel.open\n\n")
    }

    func testASpotThatListsAnEventCanShowInTheMenuBar() throws {
        try script(toml: "[on]\n\"app.front\" = true", "printf 'text=t\\ntitle=T\\n'")
        XCTAssertTrue(try sheet().spot.canShowInMenuBar)
    }

    func testTheMacRaisesTheFrontAppAndTheScreenWake() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"app.front\" = true\n\"screen.wake\" = true", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }

        mac.heard?(.named(EventName.frontApp, value: "com.apple.Safari"))
        try await wait("the front app read") { self.log("reasons") == ["spot.want none", "app.front com.apple.Safari"] && !self.runs.isShowing }
        mac.heard?(.named(EventName.screenWake, value: nil))

        try await wait("the screen wake read") { self.log("reasons") == ["spot.want none", "app.front com.apple.Safari", "screen.wake none"] }
    }

    func testTheMacRaisesTheWakeOfTheMac() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\nevery = 600", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["every none"] && !self.runs.isShowing }

        mac.heard?(.wake)

        try await wait("the wake read") { self.log("reasons") == ["every none", "every none"] }
    }

    func testAChangeOfTheClipboardRaisesClipboard() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("a look at the clipboard") { self.mac.looks > 1 }
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }

        mac.count += 1

        try await wait("the clipboard read") { self.log("reasons") == ["spot.want none", "clipboard.change none"] }
    }

    func testTheClipboardIsWatchedOnlyWhileSomethingWantsASpotThatListsIt() async throws {
        try script("other", toml: "[on]\n\"panel.open\" = true", log: "other", "printf 'text=o\\ntitle=O\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)
        XCTAssertEqual(mac.looks, 0)

        try script(toml: "[on]\n\"clipboard.change\" = true", "printf 'text=t\\ntitle=T\\n'")
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
        try script(toml: "[on]\n\"panel.open\" = true\n\"clipboard.change\" = true", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        XCTAssertFalse(runs.watchesClipboard)

        runs.panelOpened()
        XCTAssertTrue(runs.watchesClipboard)

        runs.panelClosed()
        XCTAssertFalse(runs.watchesClipboard)
    }

    func testWithThePanelClosedTheClipboardIsLookedAtAfterTwiceItsPause() async throws {
        runs.quit()
        let quiet = FakeClock()
        runs = SpotRuns(clock: quiet.value, stopPause: 0.2, clipboardPause: .milliseconds(20))
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()

        runs.listen(to: mac)
        try await wait("the pause of the watch") { quiet.isSleeping(for: 0.04) }
        let looks = mac.looks
        quiet.advance(by: 0.02)
        XCTAssertTrue(quiet.isSleeping(for: 0.02))
        quiet.advance(by: 0.03)

        try await wait("the next look") { self.mac.looks == looks + 1 }
    }

    func testOpeningThePanelLooksAtTheClipboardAtOnce() async throws {
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, clipboardPause: .seconds(4))
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "\(reasons)\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }
        mac.count = 1

        runs.panelOpened()

        try await wait("the clipboard read") { self.log("reasons").contains("clipboard.change none") }
    }

    func testNothingWatchesTheClipboardAfterAQuit() throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "printf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)

        runs.quit()
        _ = try scanned()

        XCTAssertFalse(runs.watchesClipboard)
    }

    func testAQuitEndsTheWatchOfTheClipboard() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"clipboard.change\" = true", "printf 'text=t\\ntitle=T\\n'")
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
        try script("one", toml: "[on]\n\"system.load\" = true", log: "one", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("one-reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        try script("two", toml: "[on]\n\"system.load\" = 'cpu=[0-9]+'", log: "two", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("two-reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        _ = try scanned()
        runs.listen(to: mac)
        fake.advance(by: 60)
        XCTAssertFalse(runs.watchesLoad)
        XCTAssertEqual(mac.samples, 0)

        menuBar = ["one", "two"]
        _ = try scanned()
        XCTAssertTrue(runs.watchesLoad)
        XCTAssertEqual(mac.samples, 1)
        try await wait("the first reads") { self.log("one-reasons") == ["spot.want none"] && self.log("two-reasons") == ["spot.want none"] && !self.runs.isShowing }
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
        try script("one", toml: "[on]\n\"system.load\" = true", log: "one", "\(TestSpot.event)\necho \"$ev ${val:-none}\" >> '\(path("reasons"))'\nprintf 'text=t\\ntitle=T\\n'")
        runs.listen(to: mac)
        menuBar = ["one"]
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["spot.want none"] && !self.runs.isShowing }
        menuBar = []
        _ = try scanned()
        fake.advance(by: 3)
        mac.sample = LoadSample(busy: 20, total: 100, memory: 40)

        menuBar = ["one"]
        _ = try scanned()

        try await wait("the load at once") { self.log("reasons").contains("system.load cpu=20 memory=40") && !self.runs.isShowing }
        menuBar = []
        _ = try scanned()
        fake.advance(by: 11)
        mac.sample = LoadSample(busy: 50, total: 200, memory: 40)
        menuBar = ["one"]
        _ = try scanned()
        try await wait("the watch") { self.runs.watchesLoad && fake.isSleeping(for: 5) && !self.runs.isShowing }
        try await allEnded()

        XCTAssertEqual(log("reasons").filter { $0.hasPrefix("system.load") }, ["system.load cpu=20 memory=40"])
    }
}
