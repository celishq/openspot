import XCTest
@testable import OpenspotCore

@MainActor
final class SpotDropTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private let clock = FakeClock()

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot drop \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns(clock: RunClock(now: { [clock] in clock.time }))
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(name))
    }

    private func file(_ name: String) -> String {
        FileManager.default.createFile(atPath: path(name), contents: Data())
        return path(name)
    }

    private func directory(_ name: String) throws -> String {
        try FileManager.default.createDirectory(atPath: path(name), withIntermediateDirectories: true)
        return path(name)
    }

    private func log() -> [String] {
        ((try? String(contentsOfFile: path("log"), encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
    }

    private func sheet(toml: String = "", stays: Bool = false, _ body: String = "") throws -> SpotRun {
        let url = folder.spotFile("script")
        let files = stays ? "" : "in=$(cat)\nif [ \"$1\" = drop ]; then IFS='\n'; set -- drop $(printf '%s\\n' \"$in\" | sed -n 's/^input\\.file=//p'); unset IFS; fi\n"
        try TestSpot(toml: toml, body: "\(files)echo $$ >> '\(path("pids"))'\necho \"$*\" >> '\(path("log"))'\n\(body)").write(to: url)
        let scan = try SpotsFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        runs.take(scan)
        return try XCTUnwrap(runs.sheets["script"])
    }

    private func allEnded() async throws {
        let text = (try? String(contentsOfFile: path("pids"), encoding: .utf8)) ?? ""
        let pids = text.split(separator: "\n").compactMap { Int32($0) }
        try await wait("the end of each script") { pids.allSatisfy { kill($0, 0) != 0 } }
    }

    private var untilRelease: String {
        "n=0; while [ ! -f '\(path("release"))' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
    }

    private func pause(_ seconds: Double = 0.15) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    private func command(drop: [String]) -> Spot {
        Spot(id: "a", name: "A", url: folder, triggers: Manifest.Triggers(drop: DropKinds(drop)))
    }

    func testACardTakesOnlyFilesWhoseExtensionItsDropLists() {
        let card = command(drop: ["mov", "mkv"])

        XCTAssertTrue(card.takes(paths: [file("a.mov")]))
        XCTAssertTrue(card.takes(paths: [file("a.mov"), file("b.mkv")]))
        XCTAssertFalse(card.takes(paths: [file("a.txt")]))
        XCTAssertFalse(card.takes(paths: [file("mov")]))
    }

    func testOneFileThatDoesNotFitRefusesTheWholeMix() {
        let card = command(drop: ["mov"])

        XCTAssertFalse(card.takes(paths: [file("a.mov"), file("b.txt")]))
        XCTAssertFalse(card.takes(paths: [file("b.txt"), file("a.mov")]))
    }

    func testAnExtensionMatchesInAnyCase() {
        XCTAssertTrue(command(drop: ["mov"]).takes(paths: [file("A.MOV")]))
        XCTAssertTrue(command(drop: ["MOV"]).takes(paths: [file("a.mov")]))
        XCTAssertTrue(command(drop: ["FOLDER"]).takesFolders)
    }

    func testAFolderFitsOnlyTheWordFolderAndAStar() throws {
        let plain = try directory("plain")
        let named = try directory("clip.mov")

        XCTAssertTrue(command(drop: ["folder"]).takes(paths: [plain, named]))
        XCTAssertFalse(command(drop: ["mov"]).takes(paths: [plain]))
        XCTAssertFalse(command(drop: ["mov"]).takes(paths: [named]))
    }

    func testTheWordFolderIsNotAnExtension() {
        XCTAssertFalse(command(drop: ["folder"]).takes(paths: [file("a.folder")]))
        XCTAssertFalse(command(drop: ["folder"]).takes(paths: [file("a.mov")]))
    }

    func testAStarTakesEachFileAndEachFolder() throws {
        let card = command(drop: ["*"])

        XCTAssertTrue(card.takes(paths: [file("a.mov"), file("no-extension"), try directory("plain")]))
    }

    func testACardWithNoDropTakesNothing() {
        XCTAssertFalse(command(drop: []).takes(paths: [file("a.mov")]))
        XCTAssertFalse(command(drop: [""]).takes(paths: [file("no-extension")]))
    }

    func testNoFilesAndAMissingFileAreNotTaken() {
        XCTAssertFalse(command(drop: ["*"]).takes(paths: []))
        XCTAssertFalse(command(drop: ["*"]).takes(paths: [path("gone.mov")]))
    }

    func testAPathWithSpacesAndALeadingDashIsTaken() {
        XCTAssertTrue(command(drop: ["mov"]).takes(paths: [file("a b c.mov"), file("-rf.mov"), file("--.mov")]))
    }

    func testAChoiceOffersWhatTheDropTakes() {
        XCTAssertTrue(command(drop: ["mov"]).takesFiles)
        XCTAssertFalse(command(drop: ["mov"]).takesFolders)
        XCTAssertFalse(command(drop: ["folder"]).takesFiles)
        XCTAssertTrue(command(drop: ["folder"]).takesFolders)
        XCTAssertTrue(command(drop: ["*"]).takesFiles)
        XCTAssertTrue(command(drop: ["*"]).takesFolders)
        XCTAssertFalse(command(drop: []).takesFiles)
        XCTAssertFalse(command(drop: []).takesFolders)
        XCTAssertFalse(command(drop: [""]).takesFiles)
    }

    func testAHeaderWithDropScansToACardThatTakesItsFiles() throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\", \"MKV\", \"folder\"]")

        XCTAssertTrue(sheet.spot.takes(paths: [file("a.mkv"), try directory("plain")]))
        XCTAssertFalse(sheet.spot.takes(paths: [file("a.txt")]))
    }

    private func addScript(_ name: String, toml: String) throws {
        let url = folder.spotFile(name)
        try "#!/bin/sh\n".writeScript(to: url, toml: toml)
        runs.take(try SpotsFolder(url: folder).scan())
    }

    private func cardsThatTakeTheDrag() -> Set<String> {
        Set(runs.sheets.keys.filter { runs.takesDrag($0) })
    }

    func testForTheWholeDragEachCardThatTakesEachFileShowsItAndNoOtherDoes() throws {
        try addScript("movies", toml: "[on]\ndrop = [\"mov\"]")
        try addScript("clips", toml: "[on]\ndrop = [\"mov\", \"mkv\"]")
        try addScript("all", toml: "[on]\ndrop = [\"*\"]")
        try addScript("folders", toml: "[on]\ndrop = [\"folder\"]")
        try addScript("plain", toml: "title = 'Plain'")
        XCTAssertEqual(cardsThatTakeTheDrag(), [])

        runs.dragged = FileKinds.Disk().read([file("a.mov")])
        XCTAssertEqual(cardsThatTakeTheDrag(), ["movies", "clips", "all"])

        runs.dragged = FileKinds.Disk().read([file("a.mov"), file("b.mkv")])
        XCTAssertEqual(cardsThatTakeTheDrag(), ["clips", "all"])

        runs.dragged = FileKinds.Disk().read([file("a.mov"), file("b.txt")])
        XCTAssertEqual(cardsThatTakeTheDrag(), ["all"])

        runs.dragged = FileKinds.Disk().read([try directory("plain folder")])
        XCTAssertEqual(cardsThatTakeTheDrag(), ["all", "folders"])

        runs.dragged = FileKinds.Disk().read([])
        XCTAssertEqual(cardsThatTakeTheDrag(), [])
    }

    func testACardKnowsItTakesTheDragFromTheStartOfTheDragWithNoNewLookAtTheFiles() throws {
        try addScript("movies", toml: "[on]\ndrop = [\"mov\"]")
        let movie = file("a.mov")
        runs.dragged = FileKinds.Disk().read([movie])

        try FileManager.default.removeItem(atPath: movie)

        XCTAssertTrue(runs.takesDrag("movies"))
    }

    func testACardThatIsNotAScriptNeverTakesADrag() {
        runs.dragged = FileKinds.Disk().read([file("a.mov")])

        XCTAssertFalse(runs.takesDrag("gone"))
    }

    func testADragRunsNoScript() async throws {
        try addScript("movies", toml: "[on]\ndrop = [\"mov\"]")
        let frames = FrameLog(try XCTUnwrap(runs.sheets["movies"]))
        runs.dragged = FileKinds.Disk().read([file("a.mov")])

        XCTAssertTrue(runs.takesDrag("movies"))

        try await pause()
        XCTAssertEqual(runs.sheets["movies"]?.calls.count, 0)
        XCTAssertTrue(frames.frames.isEmpty)
    }

    func testADropRunsOneCallWithEachPathAsItsOwnInput() async throws {
        let sheet = try sheet(toml: "\(TestSpot.command)\n\n[on]\ndrop = [\"mov\"]", """
        printf '%s\\n' "$in" | grep '^input\\.' > '\(path("arguments"))'
        """)
        let paths = [file("a b c.mov"), file("-rf.mov"), file("--.mov"), file("quoted \"name\".mov")]

        XCTAssertTrue(sheet.drop(paths: paths))

        try await wait("the call") { sheet.calls.isEmpty && self.log().count == 1 }
        let lines = try String(contentsOfFile: path("arguments"), encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, paths.map { "input.file=\($0)" })
        XCTAssertEqual(log(), ["drop " + paths.joined(separator: " ")])
    }

    func testAStarTakesFilesAndNoUrlOrText() {
        let card = command(drop: ["*"])

        XCTAssertFalse(card.takes(AttachmentValue(url: "https://example.com")))
        XCTAssertFalse(card.takes(AttachmentValue(text: "hola")))
        XCTAssertTrue(card.takes(AttachmentValue(files: FileKinds.Disk().read([file("a.mov")]))))
    }

    func testFilesAreTakenByTheirExtensionsAsADragIs() {
        let card = command(drop: ["mov"])

        XCTAssertTrue(card.takes(AttachmentValue(files: FileKinds.Disk().read([file("a.mov")]))))
        XCTAssertFalse(card.takes(AttachmentValue(files: FileKinds.Disk().read([file("a.txt")]))))
        XCTAssertFalse(card.takes(AttachmentValue(url: "https://example.com")))
    }

    func testADropThatTheCardDoesNotTakeRunsNothing() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]")

        XCTAssertFalse(sheet.drop(paths: [file("a.mov"), file("b.txt")]))
        XCTAssertFalse(sheet.drop(paths: []))

        try await pause()
        XCTAssertEqual(log(), [])
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    private func busySheet() async throws -> SpotRun {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", """
        case "$1" in
          show) printf 'button=work\\ntitle=Work\\nscope=spot\\n\\nitem=a\\ntitle=A\\n' ;;
          work) \(untilRelease); touch '\(path("worked"))' ;;
        esac
        """)
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 && sheet.calls.isEmpty }
        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first), item: nil)
        try await wait("the call") { self.log() == ["show", "work"] }
        return sheet
    }

    func testADropOnACardWithARunningCallWaitsAndDoesNotStopIt() async throws {
        let sheet = try await busySheet()
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop(paths: [file]))
        try await pause()

        XCTAssertEqual(log(), ["show", "work"])
        XCTAssertEqual(sheet.calls.map(\.handler), ["work"])

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertTrue(exists("worked"))
    }

    func testAWaitingDropRunsAfterTheRunningCallIsStopped() async throws {
        let sheet = try await busySheet()
        let file = file("a.mov")
        XCTAssertTrue(sheet.drop(paths: [file]))

        sheet.stop(try XCTUnwrap(sheet.calls.first))

        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertFalse(exists("worked"))
    }

    func testAWaitingDropRunsAfterASecondPressStopsTheRunningCard() async throws {
        let sheet = try sheet(toml: "\(TestSpot.command)\n\n[on]\ndrop = [\"mov\"]", "case \"$2\" in *first.mov) sleep 30 ;; esac")
        let first = file("first.mov")
        let second = file("second.mov")
        XCTAssertTrue(sheet.drop(paths: [first]))
        try await wait("the first drop") { self.log() == ["drop \(first)"] }
        XCTAssertTrue(sheet.drop(paths: [second]))
        try await pause(0.1)
        XCTAssertEqual(log(), ["drop \(first)"])

        clock.advance(by: 1)
        sheet.pressCard()

        try await wait("the second drop") { self.log() == ["drop \(first)", "drop \(second)"] }
    }

    func testAWaitingDropRunsAfterTheRunningCallFails() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", """
        case "$1" in
          show) printf 'button=work\\ntitle=Work\\nscope=spot\\n\\nitem=a\\ntitle=A\\n' ;;
          work) sleep 0.2; echo gone >&2; exit 3 ;;
        esac
        """)
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 && sheet.calls.isEmpty }
        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first), item: nil)
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop(paths: [file]))

        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertEqual(failures, ["gone"])
    }

    func testTwoWaitingDropsRunInTurn() async throws {
        let sheet = try await busySheet()
        let first = file("first.mov")
        let second = file("second.mov")
        XCTAssertTrue(sheet.drop(paths: [first]))
        XCTAssertTrue(sheet.drop(paths: [second]))

        FileManager.default.createFile(atPath: path("release"), contents: Data())

        try await wait("both drops") { self.log().filter { $0.hasPrefix("drop") } == ["drop \(first)", "drop \(second)"] }
    }

    func testASecondDropWaitsForTheFirstDrop() async throws {
        let sheet = try sheet(toml: "\(TestSpot.command)\n\n[on]\ndrop = [\"mov\"]", "case \"$2\" in *first.mov) \(untilRelease); touch '\(path("first-done"))' ;; esac")
        let first = file("first.mov")
        let second = file("second.mov")

        XCTAssertTrue(sheet.drop(paths: [first]))
        XCTAssertTrue(sheet.drop(paths: [second]))
        try await wait("the first drop") { self.log() == ["drop \(first)"] }
        try await pause()
        XCTAssertEqual(self.log(), ["drop \(first)"])
        XCTAssertEqual(sheet.calls.count, 1)

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the second drop") { self.log() == ["drop \(first)", "drop \(second)"] }
        XCTAssertTrue(exists("first-done"))
    }

    func testARunningReadDoesNotHoldADrop() async throws {
        let sheet = try sheet(toml: "[on]\n\"panel.open\" = true\ndrop = [\"mov\"]", """
        [ "$1" = show ] && { printf 'switch=power\\nclass=card:flex\\nvalue=false\\n---\\n'; sleep 30; }
        exit 0
        """)
        runs.panelOpened()
        try await wait("the read") { self.log() == ["show"] && sheet.spot.kind == .toggle }
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop(paths: [file]))

        try await wait("the drop") { self.log().contains("drop \(file)") }
    }

    func testQuittingDropsAWaitingDrop() async throws {
        let sheet = try await busySheet()
        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))

        runs.quit()
        try await pause(0.25)

        XCTAssertEqual(log(), ["show", "work"])
    }

    private func stayingSheet(toml: String = "") throws -> SpotRun {
        try sheet(toml: "stay = true\n\n[on]\ndrop = [\"mov\"]", stays: true, """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nitem=a\\ntitle=A\\n---\\n' "$call"
        done
        """)
    }

    private func blocks() -> [String] {
        let text = (try? String(contentsOfFile: path("blocks"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }.map { block in
            block.split(separator: "\n").filter { line in !["call=", "input.event=", "setting."].contains { line.hasPrefix($0) } }.joined(separator: "\n")
        }
    }

    func testADropReachesTheRunningStayingScriptAsOneBlockWithAValueLineForEachPath() async throws {
        let sheet = try stayingSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let spaced = file("a b c.mov")
        let dashed = file("-rf.mov")

        XCTAssertTrue(sheet.drop(paths: [spaced, dashed]))

        try await wait("the call and its end") { self.blocks() == ["arg=show", "arg=drop\ninput.file=\(spaced)\ninput.file=\(dashed)"] && sheet.calls.isEmpty }
        XCTAssertEqual(log().count, 1)
    }

    func testADropStartsOneCopyOfAStayingScriptThatNothingWants() async throws {
        let sheet = try stayingSheet()
        let spaced = file("a b c.mov")
        let dashed = file("-rf.mov")

        XCTAssertTrue(sheet.drop(paths: [spaced, dashed]))

        try await wait("the call") { self.blocks() == ["arg=show", "arg=drop\ninput.file=\(spaced)\ninput.file=\(dashed)"] }
        XCTAssertEqual(log(), [""])
    }

    func testTwoDropsReachOneRunningStayingScriptInTurn() async throws {
        let sheet = try stayingSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let first = file("first.mov")
        let second = file("second.mov")

        XCTAssertTrue(sheet.drop(paths: [first]))
        XCTAssertTrue(sheet.drop(paths: [second]))

        try await wait("the calls") { self.blocks() == ["arg=show", "arg=drop\ninput.file=\(first)", "arg=drop\ninput.file=\(second)"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAClickOnACardWithNoDropRunsItsCall() async throws {
        let sheet = try sheet(toml: TestSpot.command)

        sheet.pressCard()

        try await wait("the call") { self.log() == ["press"] }
    }

    func testAPressOnARunningDropStopsIt() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", "sleep 5\ntouch '\(path("went-on"))'")
        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the call") { self.log().count == 1 }

        clock.advance(by: 1)
        sheet.pressCard()

        XCTAssertFalse(sheet.isCardRunning)
        try await allEnded()
        XCTAssertFalse(exists("went-on"))
    }

    func testAPressWithinOneSecondOfADropDoesNothing() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", "sleep 0.2\ntouch '\(path("done"))'")
        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))

        sheet.pressCard()

        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the end of the work") { self.exists("done") }
    }

    func testAToggleWithDropKeepsItsClick() async throws {
        let sheet = try sheet(toml: "[on]\n\"panel.open\" = true\ndrop = [\"mov\"]", "[ \"$1\" = show ] && printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'\n[ \"$1\" = power ] && printf '%s\\n' \"$in\" | sed -n 's/^input\\.value=//p' > '\(path("value"))'\nexit 0")
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()

        try await wait("the call") { self.log().contains("power") }
        try await wait("the value of the call") { (try? String(contentsOfFile: self.path("value"), encoding: .utf8)) == "true\n" }
    }

    func testADropHasNoTimeLimitAndGoesOnWithThePanelClosed() async throws {
        runs = SpotRuns(showLimit: 0.2, clock: RunClock(now: { [clock] in clock.time }))
        let sheet = try sheet(toml: "\(TestSpot.command)\n\n[on]\ndrop = [\"mov\"]", "sleep 0.5\ntouch '\(path("done"))'")
        runs.panelOpened()
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }
        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))

        runs.panelClosed()
        XCTAssertEqual(sheet.calls.first?.isAct, true)

        try await wait("the end of the work") { self.exists("done") && sheet.calls.isEmpty }
        XCTAssertEqual(failures, [])
    }

    func testADropShowsItsFramesAndItsToastAndKeepsItsLastFrame() async throws {
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: FakeRunningApp(), runs: runs)
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", "printf 'frame=\\ntitle=42%%\\nprogress=0.42\\n---\\n'\n\(untilRelease)\n\(TestSpot.toast) Done")
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let note) = $0 { toasts.append(note.words) } }
        let frames = FrameLog(sheet)

        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))

        try await wait("the frame") { sheet.calls.first?.status != nil }
        XCTAssertEqual(sheet.calls.first?.handler, "drop")
        XCTAssertEqual(sheet.calls.first?.title, "42%")
        XCTAssertEqual(sheet.calls.first?.fill, 0.42)
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the toast") { toasts == ["Done"] }
        XCTAssertEqual(frames.last, "frame=\ntitle=42%\nprogress=0.42\n")
    }

    func testAFailedDropTellsThePerson() async throws {
        let sheet = try sheet(toml: "\(TestSpot.command)\n\n[on]\ndrop = [\"mov\"]", "echo broken >&2\nexit 2")
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }

        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))

        try await wait("the failure") { failures == ["broken"] }
    }

    func testAStoppedDropChangesNothingAndItsSilenceIsNoAnswer() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", """
        case "$1" in
          show) printf 'item=a\\ntitle=A\\n' ;;
          drop) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertTrue(sheet.drop(paths: [file("a.mov")]))
        try await wait("the call") { self.log().count == 2 }

        sheet.stop(try XCTUnwrap(sheet.calls.first))
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(log().count, 2)
    }

    func testADropWithNoFrameReadsOnce() async throws {
        let sheet = try sheet(toml: "[on]\ndrop = [\"mov\"]", "[ \"$1\" = show ] && printf 'item=a\\ntitle=A\\n'\nexit 0")
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop(paths: [file]))

        try await wait("the read after the call") { self.log() == ["drop \(file)", "show"] }
    }
}
