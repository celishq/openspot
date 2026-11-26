import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentReadTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")
    private let reads = FakeReads()
    private let add = "url=https://example.com/a title=A"

    private var shown: [String] {
        model.visible.map(\.state.title)
    }

    private var isReading: Bool {
        model.sheets["tab"]?.calls.isEmpty == false
    }

    private func refuseSafari() throws {
        let core = folder.appendingPathComponent("core", isDirectory: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: stopPause))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(reads: reads), places: model.files, app: ModelApp(model: model), runs: model.runs)
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .denied])
        try taker(takes: "'url'")
        try pickSource(runs: "\(cli) browser tab com.apple.Safari || exit")
    }

    private func refuse() async throws {
        try refuseSafari()
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the refusal") { self.chips.map(\.state) == [.failed("Openspot can't read Safari. Allow it in Openspot's settings.")] }
    }

    func testAnAttachSourceShowsItsChipUnreadAtTheOpenAndRunsNothingUntilTab() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "\(cli) attachment add \(add)")
        try witness()

        await open()
        try await wait("the spots of the open") { self.log("witness-log").count == 1 }

        XCTAssertEqual(chips.map(\.source), ["tab"])
        XCTAssertEqual(chips.map(\.state), [.unread])
        XCTAssertTrue(model.hint.hasPrefix("⇥ Attach"))
        XCTAssertEqual(log("tab-log"), [])
    }

    func testAnAttachSourceOverAnotherAppShowsNoChip() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "\(cli) attachment add \(add)")
        host.frontApp = FrontApp(bundleID: "com.apple.finder")

        await open()

        XCTAssertEqual(chips, [])
    }

    func testTabReadsTheChipOnceAndShowsReadingThenItsPreviewAndRows() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(chips.map(\.state), [.loading])
        XCTAssertEqual(model.details?.label, "Reading Safari…")
        XCTAssertEqual(shown, [])
        unblock()
        try await wait("the rows of the value") { self.shown == ["keep"] }
        XCTAssertEqual(model.details?.label, "A")
        try await wait("the end of the read") { !self.isReading }
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertFalse(isReading)
        XCTAssertEqual(log("tab-log"), ["pick"])
    }

    func testAReadThatAddsNothingSaysSoAndReturnDoesNothing() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "true")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
        model.runSelected()

        XCTAssertEqual(model.details?.label, "Nothing to attach from Safari")
        XCTAssertEqual(shown, [])
        XCTAssertTrue(model.attachments.isOn)
        XCTAssertEqual(log("keep-drops"), [])
        XCTAssertNil(model.openSheetID)
    }

    func testAnAddOfOnlyATitleFailsWithExit2AndTheChipSaysNothingToAttach() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "\(cli) attachment add 'title=Nothing selected in Finder' 2>> '\(path("errors"))'")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the end of the source") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["2"])
        XCTAssertEqual(log("errors"), [AttachmentCall.oneKind])
        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
    }

    func testARecordOnStdinOfOnlyATitleAddsNothing() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "echo title=Selected text | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
    }

    func testAReadWithNoAnswerFailsAtTheLimitAndTheNextTabReadsAgain() async throws {
        model.quit()
        model = SpotsModel(host: host, files: model.files, runs: SpotRuns(attachLimit: 0.5, stopPause: stopPause))
        host.model = model
        takeCalls()
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the failure") { self.chips.map(\.state) == [.failed("Safari didn't answer")] }
        XCTAssertEqual(model.details?.label, "Safari didn't answer")
        XCTAssertFalse(isReading)
        XCTAssertEqual(log("done"), [])
        XCTAssertEqual(host.notes, [])

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(chips.map(\.state), [.loading])
        try await wait("the second read") { self.log("tab-log") == ["pick", "pick"] }
    }

    func testAReadThatFailsShowsItsFailureLineAndNoToast() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "echo 'The tab is gone.' >&2; exit 1")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the failure") { if case .failed = self.chips.first?.state { true } else { false } }
        let line = try XCTUnwrap(model.details?.label)
        XCTAssertTrue(line.contains("The tab is gone."), line)
        XCTAssertEqual(chips.map(\.state), [.failed(line)])
        XCTAssertEqual(shown, [])
        XCTAssertEqual(host.notes, [])
    }

    func testEscWhileReadingStopsTheReadAndLeavesTheChipUnread() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["pick"] }

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertEqual(chips.map(\.state), [.unread])
        try await wait("the stop of the read") { !self.isReading }
        unblock()
        XCTAssertEqual(log("done"), [])
        XCTAssertEqual(chips.map(\.state), [.unread])
        XCTAssertTrue(model.hint.hasPrefix("⇥ Attach"))
    }

    func testTheEndOfAStoppedReadLeavesTheNextReadOfTheChipLoading() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["pick"] }

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.handleKey(tab))

        try await wait("the end of the stopped read") { self.model.runs.usage.counts["tab"]?.runs == 1 }
        XCTAssertEqual(chips.map(\.state), [.loading])
        try await wait("the start of the second read") { self.log("tab-log") == ["pick", "pick"] }
        unblock()
        try await wait("the value of the second read") { self.shown == ["keep"] }
    }

    func testANewReadStopsTheReadItReplacesAndOnlyItsValueLands() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["pick"] }

        model.runs.pickAttachment("tab", over: "com.apple.Safari") { _ in }

        try await wait("the start of the second read") { self.log("tab-log") == ["pick", "pick"] }
        try await wait("the end of the replaced read") { self.model.runs.usage.counts["tab"]?.runs == 1 }
        unblock()
        try await wait("the value of the second read") { self.shown == ["keep"] }
        try await wait("the end of the second read") { self.log("done") == ["0"] }
    }

    func testARefusedReadOffersAllowAndReturnOpensTheSettingsOfItsSource() async throws {
        try await refuse()

        XCTAssertEqual(model.details?.label, "Openspot can't read Safari. Allow it in Openspot's settings.")
        XCTAssertEqual(model.attachmentHint, "⏎ Allow   ⇥ Next   ⌘K Settings   Esc Leave")
        XCTAssertEqual(shown, [])
        XCTAssertEqual(host.notes, [])
        model.runSelected()

        XCTAssertEqual(host.settingsOpens, 1)
        XCTAssertEqual(model.settingsBook.page, .spotOf("tab"))
        XCTAssertNil(model.openSheetID)
    }

    func testCommandKOnAChipOpensTheSettingsOfItsSource() async throws {
        try await refuse()

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        XCTAssertEqual(host.settingsOpens, 1)
        XCTAssertEqual(model.settingsBook.page, .spotOf("tab"))
        XCTAssertNil(model.menu)
    }

    func testASlashWordWhileAChipReadsCompletesItsCommandAndTheChipStillFills() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']", "printf 'text=x\\ntitle=Translate\\n'")
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))

        model.query = "/tra"
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.query, "/translate ")
        XCTAssertEqual(chips.map(\.state), [.loading])
        unblock()
        try await wait("the value") { self.chips.first?.value != nil }
        model.query = ""
        XCTAssertEqual(shown, ["keep"])
    }

    func testAReopenWhileAChipReadsShowsItUnreadAndTheNextTabReadsAgain() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["pick"] }

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertEqual(chips.map(\.state), [.unread])
        XCTAssertNil(model.details)
        try await wait("the stop of the read") { !self.isReading }
        unblock()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the value of the second read") { self.shown == ["keep"] }
        XCTAssertEqual(log("tab-log"), ["pick", "pick"])
    }

    func testATakerThatArrivesAfterARefusalShowsNoRow() async throws {
        try await refuse()

        try taker("save", takes: "'url'")
        await model.reload()

        XCTAssertEqual(chips.map(\.state), [.failed("Openspot can't read Safari. Allow it in Openspot's settings.")])
        XCTAssertEqual(model.details?.label, "Openspot can't read Safari. Allow it in Openspot's settings.")
        XCTAssertEqual(shown, [])
    }

    func testTypingHidesTheUnreadChipAsBefore() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "\(cli) attachment add \(add)")
        await open()

        model.search("k")
        XCTAssertTrue(model.isAttachmentHidden)
        model.search("")
        XCTAssertFalse(model.isAttachmentHidden)
        XCTAssertEqual(log("tab-log"), [])
    }

    func testTheActionsMenuHasNoTargetOnTheEmptyLine() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "true")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the empty chip") { if case .empty = self.chips.first?.state { true } else { false } }

        XCTAssertNil(model.target)
        XCTAssertFalse(model.openSelectedSettings())
    }

    func testAttachmentAddTakesTheRecordOfReadOnStdinAndIgnoresItsOtherKeys() async throws {
        try taker(takes: "'url', 'text'")
        try pickSource(runs: "printf 'url=https://a.com/x\\ntitle=A page\\nage=5\\napp=com.apple.Safari\\n' | \(cli) attachment add")
        try pickSource("selection", runs: "printf 'text=two\\\\nlines\\napp=com.apple.Safari\\n' | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))

        try await wait("both values") { self.chips.allSatisfy { $0.value != nil } }
        XCTAssertEqual(chips.first { $0.source == "tab" }?.value, AttachmentValue(url: "https://a.com/x", title: "A page", app: "com.apple.Safari"))
        XCTAssertEqual(chips.first { $0.source == "selection" }?.value, AttachmentValue(text: "two\nlines", app: "com.apple.Safari"))
        try await wait("the end of both reads") { self.log("done") == ["0", "0"] }
    }

    func testAttachmentAddWithNothingOnStdinAddsNothingAndEndsWell() async throws {
        try taker(takes: "'url'")
        try pickSource(runs: "printf '' | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
        try await wait("the end of the read") { self.log("done") == ["0"] }
    }

    func testReturnOnAFailedChipWithNoRowsOpensTheSettingsOfItsSource() async throws {
        try refuseSafari()
        try pickSource(runs: "echo 'The tab is gone.' >&2; exit 1")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the failure") { if case .failed = self.chips.first?.state { true } else { false } }

        model.runSelected()

        XCTAssertEqual(model.settingsBook.page, .spotOf("tab"))
        XCTAssertNil(model.openSheetID)
    }
}
