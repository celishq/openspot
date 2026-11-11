import XCTest
@testable import OpenspotCore

/// Proves the rules of drops with real files and real processes: which files a card takes, the arguments of its call, and
/// how a drop waits for a running call.
@MainActor
final class SpotDropTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var time = Date(timeIntervalSince1970: 1000)

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot drop \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns(now: { [unowned self] in self.time })
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

    /// A real file with this name, and its path.
    private func file(_ name: String) -> String {
        FileManager.default.createFile(atPath: path(name), contents: Data())
        return path(name)
    }

    /// A real folder with this name, and its path.
    private func directory(_ name: String) throws -> String {
        try FileManager.default.createDirectory(atPath: path(name), withIntermediateDirectories: true)
        return path(name)
    }

    /// The calls that a script logged, one line for each.
    private func log() -> [String] {
        ((try? String(contentsOfFile: path("log"), encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
    }

    /// Writes a script with these header lines, which logs each call before its body runs, and gives its sheet.
    private func sheet(header: String = "", _ body: String = "") throws -> SpotRun {
        let url = folder.appendingPathComponent("script.sh")
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\necho $$ >> '\(path("pids"))'\necho \"$*\" >> '\(path("log"))'\n\(body)\n".writeScript(to: url)
        let scan = try PluginFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        runs.take(scan)
        return try XCTUnwrap(runs.sheets["script"])
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    /// Waits for the end of each process of a script so far, after which no stopped script can act.
    private func allEnded() async throws {
        let text = (try? String(contentsOfFile: path("pids"), encoding: .utf8)) ?? ""
        let pids = text.split(separator: "\n").compactMap { Int32($0) }
        try await wait("the end of each script") { pids.allSatisfy { kill($0, 0) != 0 } }
    }

    /// A shell loop that waits for the file `release`, for 30 seconds at most.
    private var untilRelease: String {
        "n=0; while [ ! -f '\(path("release"))' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
    }

    private func pause(_ seconds: Double = 0.15) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    private func command(drop: [String]) -> Spot {
        Spot(id: "a", name: "A", url: folder, drop: drop)
    }

    // MARK: D2

    func testACardTakesOnlyFilesWhoseExtensionItsDropLists() {
        let card = command(drop: ["mov", "mkv"])

        XCTAssertTrue(card.accepts([file("a.mov")]))
        XCTAssertTrue(card.accepts([file("a.mov"), file("b.mkv")]))
        XCTAssertFalse(card.accepts([file("a.txt")]))
        XCTAssertFalse(card.accepts([file("mov")]))
    }

    func testOneFileThatDoesNotFitRefusesTheWholeMix() {
        let card = command(drop: ["mov"])

        XCTAssertFalse(card.accepts([file("a.mov"), file("b.txt")]))
        XCTAssertFalse(card.accepts([file("b.txt"), file("a.mov")]))
    }

    func testAnExtensionMatchesInAnyCase() {
        XCTAssertTrue(command(drop: ["mov"]).accepts([file("A.MOV")]))
        XCTAssertTrue(command(drop: ["MOV"]).accepts([file("a.mov")]))
        XCTAssertTrue(command(drop: ["FOLDER"]).takesFolders)
    }

    func testAFolderFitsOnlyTheWordFolderAndAStar() throws {
        let plain = try directory("plain")
        let named = try directory("clip.mov")

        XCTAssertTrue(command(drop: ["folder"]).accepts([plain, named]))
        XCTAssertFalse(command(drop: ["mov"]).accepts([plain]))
        XCTAssertFalse(command(drop: ["mov"]).accepts([named]))
    }

    func testTheWordFolderIsNotAnExtension() {
        XCTAssertFalse(command(drop: ["folder"]).accepts([file("a.folder")]))
        XCTAssertFalse(command(drop: ["folder"]).accepts([file("a.mov")]))
    }

    func testAStarTakesEachFileAndEachFolder() throws {
        let card = command(drop: ["*"])

        XCTAssertTrue(card.accepts([file("a.mov"), file("no-extension"), try directory("plain")]))
    }

    func testACardWithNoDropTakesNothing() {
        XCTAssertFalse(command(drop: []).accepts([file("a.mov")]))
        XCTAssertFalse(command(drop: [""]).accepts([file("no-extension")]))
    }

    func testNoFilesAndAMissingFileAreNotTaken() {
        XCTAssertFalse(command(drop: ["*"]).accepts([]))
        XCTAssertFalse(command(drop: ["*"]).accepts([path("gone.mov")]))
    }

    func testAPathWithSpacesAndALeadingDashIsTaken() {
        XCTAssertTrue(command(drop: ["mov"]).accepts([file("a b c.mov"), file("-rf.mov"), file("--.mov")]))
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
        let sheet = try sheet(header: "drop=mov, MKV,folder")

        XCTAssertTrue(sheet.command.accepts([file("a.mkv"), try directory("plain")]))
        XCTAssertFalse(sheet.command.accepts([file("a.txt")]))
    }

    /// Writes one more script with this header, and takes a new scan.
    private func addScript(_ name: String, header: String) throws {
        let url = folder.appendingPathComponent("\(name).sh")
        try "#!/bin/sh\n# \(header)\n".writeScript(to: url)
        runs.take(try PluginFolder(url: folder).scan())
    }

    private func cardsThatTakeTheDrag() -> Set<String> {
        Set(runs.sheets.keys.filter { runs.takesDrag($0) })
    }

    func testForTheWholeDragEachCardThatTakesEachFileShowsItAndNoOtherDoes() throws {
        try addScript("movies", header: "drop=mov")
        try addScript("clips", header: "drop=mov,mkv")
        try addScript("all", header: "drop=*")
        try addScript("folders", header: "drop=folder")
        try addScript("plain", header: "title=Plain")
        XCTAssertEqual(cardsThatTakeTheDrag(), [])

        runs.draggedPaths = [file("a.mov")]
        XCTAssertEqual(cardsThatTakeTheDrag(), ["movies", "clips", "all"])

        runs.draggedPaths = [file("a.mov"), file("b.mkv")]
        XCTAssertEqual(cardsThatTakeTheDrag(), ["clips", "all"])

        runs.draggedPaths = [file("a.mov"), file("b.txt")]
        XCTAssertEqual(cardsThatTakeTheDrag(), ["all"])

        runs.draggedPaths = [try directory("plain folder")]
        XCTAssertEqual(cardsThatTakeTheDrag(), ["all", "folders"])

        runs.draggedPaths = []
        XCTAssertEqual(cardsThatTakeTheDrag(), [])
    }

    func testACardThatIsNotAScriptNeverTakesADrag() {
        runs.draggedPaths = [file("a.mov")]

        XCTAssertFalse(runs.takesDrag("gone"))
    }

    func testADragRunsNoScript() async throws {
        try addScript("movies", header: "drop=mov")
        let frames = FrameLog(try XCTUnwrap(runs.sheets["movies"]))
        runs.draggedPaths = [file("a.mov")]

        XCTAssertTrue(runs.takesDrag("movies"))

        try await pause()
        XCTAssertEqual(runs.sheets["movies"]?.calls.count, 0)
        XCTAssertTrue(frames.frames.isEmpty)
    }

    // MARK: D3

    func testADropRunsOneCallWithEachPathAsItsOwnArgument() async throws {
        let sheet = try sheet(header: "drop=mov", """
        printf '%s\\n' "$#" > '\(path("arguments"))'
        for argument; do printf '%s\\n' "$argument" >> '\(path("arguments"))'; done
        """)
        let paths = [file("a b c.mov"), file("-rf.mov"), file("--.mov"), file("quoted \"name\".mov")]

        XCTAssertTrue(sheet.drop(paths))

        try await wait("the call") { sheet.calls.isEmpty && self.log().count == 1 }
        let lines = try String(contentsOfFile: path("arguments"), encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, ["5", "drop"] + paths)
    }

    func testAnArgumentThatStartsWithADashReachesTheScriptAsItIs() async throws {
        let url = folder.appendingPathComponent("plain.sh")
        try "#!/bin/sh\nprintf '%s|' \"$@\"\n".writeScript(to: url)

        let text = try await runs.answer(of: Spot(id: "plain", name: "Plain", url: url), .drop(paths: ["-n", "--", "a b"]))

        XCTAssertEqual(text, "drop|-n|--|a b|")
    }

    func testADropThatTheCardDoesNotTakeRunsNothing() async throws {
        let sheet = try sheet(header: "drop=mov")

        XCTAssertFalse(sheet.drop([file("a.mov"), file("b.txt")]))
        XCTAssertFalse(sheet.drop([]))

        try await pause()
        XCTAssertEqual(log(), [])
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    // MARK: D4

    /// An open sheet whose running `work` action goes on until the file `release` appears.
    private func busySheet() async throws -> SpotRun {
        let sheet = try sheet(header: "read=sheet\ndrop=mov", """
        case "$1" in
          read) printf 'button=work\\ntitle=Work\\nscope=command\\n\\nrow=a\\ntitle=A\\n' ;;
          work) \(untilRelease); touch '\(path("worked"))' ;;
        esac
        """)
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 && sheet.calls.isEmpty }
        sheet.run(try XCTUnwrap(sheet.command.actions.first), item: nil)
        try await wait("the call") { self.log() == ["read", "work"] }
        return sheet
    }

    func testADropOnACardWithARunningCallWaitsAndDoesNotStopIt() async throws {
        let sheet = try await busySheet()
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop([file]))
        try await pause()

        XCTAssertEqual(log(), ["read", "work"])
        XCTAssertEqual(sheet.calls.map(\.action.arguments), [["work"]])

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertTrue(exists("worked"))
    }

    func testAWaitingDropRunsAfterTheRunningCallIsStopped() async throws {
        let sheet = try await busySheet()
        let file = file("a.mov")
        XCTAssertTrue(sheet.drop([file]))

        sheet.stop(try XCTUnwrap(sheet.calls.first))

        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertFalse(exists("worked"))
    }

    func testAWaitingDropRunsAfterASecondPressStopsTheRunningCard() async throws {
        let sheet = try sheet(header: "drop=mov", "case \"$2\" in *first.mov) sleep 30 ;; esac")
        let first = file("first.mov")
        let second = file("second.mov")
        XCTAssertTrue(sheet.drop([first]))
        try await wait("the first drop") { self.log() == ["drop \(first)"] }
        XCTAssertTrue(sheet.drop([second]))
        try await pause(0.1)
        XCTAssertEqual(log(), ["drop \(first)"])

        time = time.addingTimeInterval(1)
        sheet.pressCard()

        try await wait("the second drop") { self.log() == ["drop \(first)", "drop \(second)"] }
    }

    func testAWaitingDropRunsAfterTheRunningCallFails() async throws {
        let sheet = try sheet(header: "read=sheet\ndrop=mov", """
        case "$1" in
          read) printf 'button=work\\ntitle=Work\\nscope=command\\n\\nrow=a\\ntitle=A\\n' ;;
          work) sleep 0.2; echo gone >&2; exit 3 ;;
        esac
        """)
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 && sheet.calls.isEmpty }
        sheet.run(try XCTUnwrap(sheet.command.actions.first), item: nil)
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop([file]))

        try await wait("the drop") { self.log().contains("drop \(file)") }
        XCTAssertEqual(failures, ["gone"])
    }

    func testTwoWaitingDropsRunInTurn() async throws {
        let sheet = try await busySheet()
        let first = file("first.mov")
        let second = file("second.mov")
        XCTAssertTrue(sheet.drop([first]))
        XCTAssertTrue(sheet.drop([second]))

        FileManager.default.createFile(atPath: path("release"), contents: Data())

        try await wait("both drops") { self.log().filter { $0.hasPrefix("drop") } == ["drop \(first)", "drop \(second)"] }
    }

    func testASecondDropWaitsForTheFirstDrop() async throws {
        let sheet = try sheet(header: "drop=mov", "case \"$2\" in *first.mov) \(untilRelease); touch '\(path("first-done"))' ;; esac")
        let first = file("first.mov")
        let second = file("second.mov")

        XCTAssertTrue(sheet.drop([first]))
        XCTAssertTrue(sheet.drop([second]))
        try await wait("the first drop") { self.log() == ["drop \(first)"] }
        try await pause()
        XCTAssertEqual(self.log(), ["drop \(first)"])
        XCTAssertEqual(sheet.calls.count, 1)

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the second drop") { self.log() == ["drop \(first)", "drop \(second)"] }
        XCTAssertTrue(exists("first-done"))
    }

    func testARunningReadDoesNotHoldADrop() async throws {
        let sheet = try sheet(header: "read=panel\ndrop=mov", """
        [ "$1" = read ] && { printf 'switch=power\\nvalue=false\\n---\\n'; sleep 30; }
        exit 0
        """)
        runs.panelOpened()
        try await wait("the read") { self.log() == ["read"] && sheet.command.kind == .toggle }
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop([file]))

        try await wait("the drop") { self.log().contains("drop \(file)") }
    }

    func testQuittingDropsAWaitingDrop() async throws {
        let sheet = try await busySheet()
        XCTAssertTrue(sheet.drop([file("a.mov")]))

        runs.quit()
        try await pause(0.25)

        XCTAssertEqual(log(), ["read", "work"])
    }

    // MARK: Y1, Y2

    /// The sheet of a staying script that takes `mov` files. It logs each line of its stdin, and prints a frame after each block.
    private func stayingSheet(header: String = "") throws -> SpotRun {
        try sheet(header: "stay=true\ndrop=mov\n\(header)", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call"
        done
        """)
    }

    /// The blocks that a staying script got, one string for each, with no `call` or `reason` line.
    private func blocks() -> [String] {
        let text = (try? String(contentsOfFile: path("blocks"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }.map { block in
            block.split(separator: "\n").filter { !$0.hasPrefix("call=") && !$0.hasPrefix("reason=") }.joined(separator: "\n")
        }
    }

    func testADropReachesTheRunningStayingScriptAsOneBlockWithAValueLineForEachPath() async throws {
        let sheet = try stayingSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let spaced = file("a b c.mov")
        let dashed = file("-rf.mov")

        XCTAssertTrue(sheet.drop([spaced, dashed]))

        try await wait("the call") { self.blocks() == ["arg=read", "arg=drop\narg=\(spaced)\narg=\(dashed)"] }
        XCTAssertEqual(log().count, 1)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testADropStartsOneCopyOfAStayingScriptThatNothingWants() async throws {
        let sheet = try stayingSheet()
        let spaced = file("a b c.mov")
        let dashed = file("-rf.mov")

        XCTAssertTrue(sheet.drop([spaced, dashed]))

        try await wait("the call") { self.blocks() == ["arg=read", "arg=drop\narg=\(spaced)\narg=\(dashed)"] }
        XCTAssertEqual(log(), [""])
    }

    func testTwoDropsReachOneRunningStayingScriptInTurn() async throws {
        let sheet = try stayingSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let first = file("first.mov")
        let second = file("second.mov")

        XCTAssertTrue(sheet.drop([first]))
        XCTAssertTrue(sheet.drop([second]))

        try await wait("the calls") { self.blocks() == ["arg=read", "arg=drop\narg=\(first)", "arg=drop\narg=\(second)"] }
        XCTAssertEqual(log().count, 1)
    }

    // MARK: D5

    /// Counts how often the sheet asks its owner for a choice of files.
    private func choiceCount(of sheet: SpotRun) -> () -> Int {
        var count = 0
        sheet.onReport = { if case .chooseFiles = $0 { count += 1 } }
        return { count }
    }

    func testAClickOnACardWithDropAndNoSheetAsksForAChoiceAndRunsNothing() async throws {
        let sheet = try sheet(header: "drop=mov")
        let choices = choiceCount(of: sheet)

        sheet.pressCard()

        XCTAssertEqual(choices(), 1)
        XCTAssertTrue(sheet.calls.isEmpty)
        try await pause()
        XCTAssertEqual(log(), [])
    }

    func testAChoiceRunsTheSameCallAsADrop() async throws {
        let sheet = try sheet(header: "drop=mov")
        sheet.pressCard()
        let file = file("a b.mov")

        XCTAssertTrue(sheet.drop([file]))

        try await wait("the call") { self.log() == ["drop \(file)"] }
    }

    func testAClickOnACardWithNoDropRunsItsCallAndAsksForNoChoice() async throws {
        let sheet = try sheet()
        let choices = choiceCount(of: sheet)

        sheet.pressCard()

        XCTAssertEqual(choices(), 0)
        try await wait("the call") { self.log() == ["open"] }
    }

    func testAPressOnARunningDropStopsItAndAsksForNoChoice() async throws {
        let sheet = try sheet(header: "drop=mov", "sleep 5\ntouch '\(path("went-on"))'")
        let choices = choiceCount(of: sheet)
        XCTAssertTrue(sheet.drop([file("a.mov")]))
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the call") { self.log().count == 1 }

        time = time.addingTimeInterval(1)
        sheet.pressCard()

        XCTAssertEqual(choices(), 0)
        XCTAssertFalse(sheet.isCardRunning)
        try await allEnded()
        XCTAssertFalse(exists("went-on"))
    }

    func testAPressWithinOneSecondOfADropDoesNothing() async throws {
        let sheet = try sheet(header: "drop=mov", "sleep 0.2\ntouch '\(path("done"))'")
        let choices = choiceCount(of: sheet)
        XCTAssertTrue(sheet.drop([file("a.mov")]))

        sheet.pressCard()

        XCTAssertEqual(choices(), 0)
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the end of the work") { self.exists("done") }
    }

    func testAToggleWithDropKeepsItsClick() async throws {
        let sheet = try sheet(header: "read=panel\ndrop=mov", "[ \"$1\" = read ] && printf 'switch=power\\nvalue=false\\n'\nexit 0")
        let choices = choiceCount(of: sheet)
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()

        XCTAssertEqual(choices(), 0)
        try await wait("the call") { self.log().contains("power true") }
    }

    // MARK: D6

    func testADropHasNoTimeLimitAndGoesOnWithThePanelClosed() async throws {
        runs = SpotRuns(readLimit: 0.2, now: { [unowned self] in self.time })
        let sheet = try sheet(header: "drop=mov", "sleep 0.5\ntouch '\(path("done"))'")
        runs.panelOpened()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        XCTAssertTrue(sheet.drop([file("a.mov")]))

        runs.panelClosed()
        XCTAssertEqual(sheet.calls.first?.doesWork, true)

        try await wait("the end of the work") { self.exists("done") && sheet.calls.isEmpty }
        XCTAssertEqual(failures, [])
    }

    func testADropShowsItsFramesAndItsToastAndKeepsItsLastFrame() async throws {
        let sheet = try sheet(header: "drop=mov", "printf 'gauge=progress\\ntitle=42%%\\nvalue=0.42\\n---\\n'\n\(untilRelease)\nprintf 'toast=Done\\n'")
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        let frames = FrameLog(sheet)

        XCTAssertTrue(sheet.drop([file("a.mov")]))

        try await wait("the frame") { sheet.calls.first?.output != nil }
        XCTAssertEqual(sheet.calls.first?.action.arguments.first, "drop")
        XCTAssertEqual(sheet.calls.first?.title, "42%")
        XCTAssertEqual(sheet.calls.first?.fill, 0.42)
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the toast") { toasts == ["Done"] }
        XCTAssertEqual(frames.last, "toast=Done\n")
    }

    func testAFailedDropTellsThePerson() async throws {
        let sheet = try sheet(header: "drop=mov", "echo broken >&2\nexit 2")
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        XCTAssertTrue(sheet.drop([file("a.mov")]))

        try await wait("the failure") { failures == ["broken"] }
    }

    func testAStoppedDropChangesNothingAndItsSilenceIsNoAnswer() async throws {
        let sheet = try sheet(header: "read=sheet\ndrop=mov", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\n' ;;
          drop) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertTrue(sheet.drop([file("a.mov")]))
        try await wait("the call") { self.log().count == 2 }

        sheet.stop(try XCTUnwrap(sheet.calls.first))
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(log().count, 2)
    }

    func testADropWithNoFrameReadsOnce() async throws {
        let sheet = try sheet(header: "read=sheet\ndrop=mov", "[ \"$1\" = read ] && printf 'row=a\\ntitle=A\\n'\nexit 0")
        let file = file("a.mov")

        XCTAssertTrue(sheet.drop([file]))

        try await wait("the read after the call") { self.log() == ["drop \(file)", "read"] }
    }

    // MARK: D8

    func testADropThatSelectsARowReadsAgainWithThatRowSelected() async throws {
        let rows = "printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'"
        let sheet = try sheet(header: "read=sheet\ndrop=mov", "case \"$1\" in\n  read) \(rows) ;;\n  drop) printf 'toast=Added\\nselect=b\\n' ;;\nesac")
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 2 }
        XCTAssertEqual(sheet.list.selectedItem?.run, "a")
        let file = file("b.mov")

        XCTAssertTrue(sheet.drop([file]))

        try await wait("the read with b selected") { self.log() == ["read", "drop \(file)", "read"] && sheet.list.selectedItem?.run == "b" }
    }
}
