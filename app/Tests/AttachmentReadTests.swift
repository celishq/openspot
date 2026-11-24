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
        model.sheets["tab"]?.isShowing ?? false
    }

    private func refuseSafari() throws {
        let core = folder.appendingPathComponent("core", isDirectory: true)
        let app = core.appendingPathComponent("openspot.spot")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try "[scripts.attachments]\ntitle = 'Attachments'\nedits = 'attachments'\n\n[scripts.attachments.on]\n\"sheet.open\" = true\n"
            .write(to: app.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\nprintf 'item=a\\ntitle=Browser Tab\\n'\n".writeScript(to: app.appendingPathComponent("attachments.sh"))
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: stopPause))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(reads: ReadSources(mac: reads)), places: model.files, app: ModelApp(model: model), runs: model.runs)
        reads.set(front: "com.apple.Safari", access: ["com.apple.Safari": .denied])
        try taker(takes: "'url'")
        try attach(runs: "\(cli) read tab")
    }

    private func refuse() async throws {
        try refuseSafari()
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the refusal") { self.chips.map(\.state) == [.denied("Safari")] }
    }

    func testAnAttachSourceShowsItsChipUnreadAtTheOpenAndRunsNothingUntilTab() async throws {
        try taker(takes: "'url'")
        try attach(runs: "\(cli) attachment add \(add)")
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
        try attach(runs: "\(cli) attachment add \(add)")
        host.frontApp = FrontApp(bundleID: "com.apple.finder")

        await open()

        XCTAssertEqual(chips, [])
    }

    func testTabReadsTheChipOnceAndShowsReadingThenItsPreviewAndRows() async throws {
        try taker(takes: "'url'")
        try attach(waits: true, runs: "\(cli) attachment add \(add)")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(chips.map(\.state), [.loading])
        XCTAssertEqual(model.fieldValue.preview?.caption, "Reading Safari…")
        XCTAssertEqual(shown, [])
        unblock()
        try await wait("the rows of the value") { self.shown == ["keep"] }
        XCTAssertEqual(model.fieldValue.preview?.text, "A")
        try await wait("the end of the read") { !self.isReading }
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertFalse(isReading)
        XCTAssertEqual(log("tab-log"), ["attach"])
    }

    func testAReadThatAddsNothingSaysSoAndReturnDoesNothing() async throws {
        try taker(takes: "'url'")
        try attach(runs: "true")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
        model.runSelected()

        XCTAssertEqual(model.fieldValue.preview?.caption, "Nothing to attach from Safari")
        XCTAssertEqual(shown, [])
        XCTAssertTrue(model.attachments.isOn)
        XCTAssertEqual(log("keep-drops"), [])
        XCTAssertNil(model.openSheetID)
    }

    func testAttachmentEmptyShowsTheWordsOfTheSource() async throws {
        try taker(takes: "'url'")
        try attach(runs: "\(cli) attachment empty Nothing selected in Finder")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the words of the source") { self.model.fieldValue.preview?.caption == "Nothing selected in Finder" }
        XCTAssertEqual(chips.map(\.state), [.empty("Nothing selected in Finder")])
    }

    func testAReadWithNoAnswerFailsAtTheLimitAndTheNextTabReadsAgain() async throws {
        try taker(takes: "'url'")
        try attach(waits: true, runs: "\(cli) attachment add \(add)")
        model.attachmentReadLimit = .milliseconds(200)
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the failure") { self.chips.map(\.state) == [.failed("Safari didn't answer")] }
        XCTAssertEqual(model.fieldValue.preview?.caption, "Safari didn't answer")
        try await wait("the stop of the read") { !self.isReading }
        XCTAssertEqual(log("done"), [])

        model.attachmentReadLimit = .seconds(60)
        unblock()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(chips.map(\.state), [.loading])
        try await wait("the value of the second read") { self.shown == ["keep"] }
        XCTAssertEqual(log("tab-log"), ["attach", "attach"])
    }

    func testAReadThatFailsShowsItsFailureLineAndNoToast() async throws {
        try taker(takes: "'url'")
        try attach(runs: "echo 'The tab is gone.' >&2; exit 1")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the failure") { if case .failed = self.chips.first?.state { true } else { false } }
        let line = try XCTUnwrap(model.fieldValue.preview?.caption)
        XCTAssertTrue(line.contains("The tab is gone."), line)
        XCTAssertEqual(chips.map(\.state), [.failed(line)])
        XCTAssertEqual(shown, [])
        XCTAssertEqual(host.notes, [])
    }

    func testEscWhileReadingStopsTheReadAndLeavesTheChipUnread() async throws {
        try taker(takes: "'url'")
        try attach(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["attach"] }

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertEqual(chips.map(\.state), [.unread])
        try await wait("the stop of the read") { !self.isReading }
        unblock()
        XCTAssertEqual(log("done"), [])
        XCTAssertEqual(chips.map(\.state), [.unread])
        XCTAssertTrue(model.hint.hasPrefix("⇥ Attach"))
    }

    func testARefusedReadOffersAllowAndReturnOpensAttachments() async throws {
        try await refuse()

        XCTAssertEqual(model.fieldValue.preview?.caption, "Openspot can't read Safari · ⏎ Allow")
        XCTAssertEqual(shown, [])
        XCTAssertEqual(host.notes, [])
        model.runSelected()

        try await wait("the Attachments sheet") { self.model.openSheetID == "openspot/attachments" }
    }

    func testASlashWordWhileAChipReadsCompletesItsCommandAndTheChipStillFills() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']", "printf 'text=x\\ntitle=Translate\\n'")
        try taker(takes: "'url'")
        try attach(waits: true, runs: "\(cli) attachment add \(add)")
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
        try attach(waits: true, runs: "\(cli) attachment add \(add)")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the start of the read") { self.log("tab-log") == ["attach"] }

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertEqual(chips.map(\.state), [.unread])
        XCTAssertNil(model.fieldValue.preview)
        try await wait("the stop of the read") { !self.isReading }
        unblock()
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the value of the second read") { self.shown == ["keep"] }
        XCTAssertEqual(log("tab-log"), ["attach", "attach"])
    }

    func testATakerThatArrivesAfterARefusalShowsNoRow() async throws {
        try await refuse()

        try taker("save", takes: "'url'")
        await model.reload()

        XCTAssertEqual(chips.map(\.state), [.denied("Safari")])
        XCTAssertEqual(model.fieldValue.preview?.caption, "Openspot can't read Safari · ⏎ Allow")
        XCTAssertEqual(shown, [])
    }

    func testTypingHidesTheUnreadChipAsBefore() async throws {
        try taker(takes: "'url'")
        try attach(runs: "\(cli) attachment add \(add)")
        await open()

        model.query = "k"
        XCTAssertTrue(model.isAttachmentHidden)
        model.query = ""
        XCTAssertFalse(model.isAttachmentHidden)
        XCTAssertEqual(log("tab-log"), [])
    }

    func testTheActionsMenuHasNoTargetOnTheEmptyLine() async throws {
        try taker(takes: "'url'")
        try attach(runs: "true")
        await open()

        XCTAssertTrue(model.handleKey(tab))
        try await wait("the empty chip") { if case .empty = self.chips.first?.state { true } else { false } }

        XCTAssertNil(model.target)
        XCTAssertFalse(model.openSelectedSettings())
    }

    func testAttachmentAddTakesTheRecordOfReadOnStdinAndIgnoresItsOtherKeys() async throws {
        try taker(takes: "'url', 'text'")
        try attach(runs: "printf 'url=https://a.com/x\\ntitle=A page\\nage=5\\napp=com.apple.Safari\\n' | \(cli) attachment add")
        try attach("selection", runs: "printf 'text=two\\\\nlines\\napp=com.apple.Safari\\n' | \(cli) attachment add")
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
        try attach(runs: "printf '' | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the empty chip") { self.chips.map(\.state) == [.empty("Nothing to attach from Safari")] }
        try await wait("the end of the read") { self.log("done") == ["0"] }
    }

    func testARefusedReadPipedToAttachmentAddOffersAllow() async throws {
        try refuseSafari()
        try attach(runs: "\(cli) read tab | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the refusal") { self.chips.map(\.state) == [.denied("Safari")] }
        try await wait("the end of the read") { self.log("done") == ["0"] }
        XCTAssertEqual(chips.map(\.state), [.denied("Safari")])
        XCTAssertEqual(host.notes, [])
    }
}
