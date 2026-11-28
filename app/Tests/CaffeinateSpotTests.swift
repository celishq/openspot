import XCTest
@testable import OpenspotCore

@MainActor
final class CaffeinateSpotTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var environment: [String: String] = [:]

    override func setUp() async throws {
        folder = try temporaryFolder()
        let f = folder.path
        try fake("caffeinate", """
            echo "$$ $*" >> '\(f)/awake'
            [ -f '\(f)/short' ] && exec /bin/sleep 0.3
            exec /bin/sleep 600
            """)
        try fake("openspot", """
            case "$1 $2" in
              'toast '*) shift; printf '%s\\n' "$*" >> '\(f)/toasts' ;;
              'setting get') cat "\(f)/setting.$3" 2>/dev/null ;;
              'setting set') printf %s "$4" > "\(f)/setting.$3" ;;
              'power lid-closed')
                if [ -f '\(f)/deny' ]; then
                  echo '\(Self.approval)' >&2
                  exit 1
                fi
                echo "$$ on" >> '\(f)/lid'
                trap 'kill $! 2>/dev/null; echo "$$ off" >> "\(f)/lid"; exit 0' TERM
                echo on
                /bin/sleep 600 &
                wait
                ;;
            esac
            """)
        try fake("ioreg", """
            [ -f '\(f)/desk' ] || echo '  | "AppleClamshellState" = No'
            """)
        environment = ["PATH": "\(folder.appendingPathComponent("tools").path):/usr/bin:/bin", "HOME": f, "TMPDIR": f + "/"]
        runs = SpotRuns(environment: environment, stopPause: 0.2)
    }

    private func fake(_ name: String, _ body: String) throws {
        try "#!/bin/sh\n\(body)\n".writeScript(to: folder.appendingPathComponent("tools").appendingPathComponent(name))
    }

    private func touch(_ name: String) {
        FileManager.default.createFile(atPath: folder.appendingPathComponent(name).path, contents: Data())
    }

    private func lidClosed() -> String? {
        try? String(contentsOf: folder.appendingPathComponent("setting.lid-closed"), encoding: .utf8)
    }

    private func keepLidClosed() throws {
        try "true".write(to: folder.appendingPathComponent("setting.lid-closed"), atomically: true, encoding: .utf8)
    }

    private func lidRow(in sheet: SpotRun) -> SpotItem? {
        row("lid", in: sheet)
    }

    private func row(_ run: String, in sheet: SpotRun) -> SpotItem? {
        sheet.list.all.first { $0.run == run }
    }

    private func setting(_ key: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent("setting.\(key)"), encoding: .utf8)
    }

    private static let approval = "Openspot needs your approval for its power helper. Turn on Openspot in Login Items & Extensions, then try again."

    private func lidHolders() -> [pid_t] {
        lines("lid").filter { $0.hasSuffix(" on") }.compactMap { $0.split(separator: " ").first.flatMap { pid_t($0) } }
    }

    private func lidIsHeld() -> Bool {
        lidHolders().contains { kill($0, 0) == 0 }
    }

    private func lidIsLetGo() -> Bool {
        !lidHolders().isEmpty && !lidIsHeld()
    }

    override func tearDown() async throws {
        runs.quit()
        for pid in awake() + lidHolders() { kill(pid, SIGKILL) }
    }

    private func spot() throws -> Spot {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try XCTUnwrap(try SpotsFolder(url: root.appendingPathComponent("spots")).scan().spots.first { $0.id == "caffeinate" })
    }

    private func lines(_ name: String) -> [String] {
        let text = (try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    private func sheet() throws -> SpotRun {
        let spot = try spot()
        let sheet = runs.sheet(for: spot)
        runs.panelOpened()
        sheet.open {}
        return sheet
    }

    private func caffeinates() -> [(pid: pid_t, flags: String)] {
        lines("awake").compactMap { line in
            let words = line.split(separator: " ")
            return words.first.flatMap { pid_t($0) }.map { ($0, words.dropFirst().joined(separator: " ")) }
        }
    }

    private func awake() -> [pid_t] {
        caffeinates().map(\.pid)
    }

    private func flags() -> [String] {
        caffeinates().map(\.flags)
    }

    private func running() -> [pid_t] {
        awake().filter { kill($0, 0) == 0 }
    }

    private func pick(_ run: String, in sheet: SpotRun) async throws {
        try await wait("the row \(run)") { sheet.list.all.contains { $0.run == run } }
        sheet.pick(try XCTUnwrap(sheet.list.all.first { $0.run == run }))
    }

    func testItOffersItsDurationsAsASheetOfRowsAlone() async throws {
        let sheet = try sheet()

        try await wait("the rows") { !sheet.list.all.isEmpty }

        XCTAssertEqual(sheet.shownState.subtitle, "Keep the Mac awake")
        XCTAssertEqual(sheet.list.all.map(\.run), ["1800", "7200", "custom", "0", "process", "display", "lid"])
        XCTAssertEqual(sheet.list.all.map(\.title), ["30 minutes", "2 hours", "Custom…", "Until turned off", "While a process runs…", "Keep the display on", "Work with the lid closed"])
        XCTAssertEqual(sheet.list.all.suffix(2).map(\.pin), [.bottom, .bottom])
        XCTAssertEqual(sheet.list.all.suffix(2).map(\.isOn), [true, false])
        XCTAssertEqual(sheet.list.all.suffix(2).map(\.isToggle), [true, true])
        XCTAssertEqual(sheet.list.all.suffix(2).map(\.symbol), ["display", "laptopcomputer"])
    }

    func testAMacWithNoLidHasNoLidRowAndAHoldIgnoresTheKeptLid() async throws {
        touch("desk")
        try keepLidClosed()
        let sheet = try sheet()

        try await wait("the rows") { !sheet.list.all.isEmpty }
        XCTAssertEqual(sheet.list.all.last?.run, "display")

        try await pick("1800", in: sheet)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(lines("lid"), [])
        XCTAssertTrue(lines("toasts").allSatisfy { !$0.contains("lid") })
    }

    func testTheRunningDurationShowsTheTimeItHasLeft() async throws {
        let sheet = try sheet()

        try await pick("7200", in: sheet)

        try await wait("the time left on the row") { sheet.list.all.first { $0.title == "2 hours" }?.subtitle == "2h 0m left" }
        XCTAssertNil(sheet.list.all.first { $0.title == "30 minutes" }?.subtitle)
    }

    func testTheCustomRowOpensAPageThatAsksForMinutesAndKeepsTheMacAwakeForThem() async throws {
        let sheet = try sheet()
        var forms: [ItemForm] = []
        sheet.onReport = { if case .form(let form) = $0 { forms.append(form) } }
        try await wait("the custom row") { self.row("custom", in: sheet) != nil }
        let item = try XCTUnwrap(row("custom", in: sheet))
        guard case .push(_, let route?, _, _)? = item.move else { return XCTFail("Custom… opens no page") }

        sheet.show(FlowSheet(spot: sheet.spot.id, route: route))
        try await wait("the form of the page") { !forms.isEmpty }
        XCTAssertEqual(forms.first?.fields.map(\.label), ["Minutes"])
        var draft = FormDraft(form: try XCTUnwrap(forms.first))
        draft.set("45", for: "minutes")
        _ = try await sheet.submit(CommandAction(id: ScriptEntry.press.name, title: item.title), item: nil, draft: draft)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -t 2700"])
    }

    private func runProcesses(git: Bool = true) throws {
        let me = getuid()
        try fake("ps", """
            case "$*" in
              *comm=*4242*) echo /usr/local/bin/claude; exit 0 ;;
              *comm=*) exit 1 ;;
            esac
            printf '%s\\n' \\
              '   50     1 \(me) ??     3-00:00:00 /Applications/Ghostty.app/Contents/MacOS/ghostty' \\
              '  100    50 \(me) ttys001    02:00:00 -zsh' \\
              ' 4242   100 \(me) ttys001    01:02:03 claude --resume abc' \\
              ' 4300  4242 \(me) ttys001       05:00 /usr/bin/sourcekit-lsp' \\
              '   60     1 \(me) ??     3-00:00:00 /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal' \\
              '  190    60     0 ttys002       10:00 login -pfl me /bin/bash' \\
              '  200   190 \(me) ttys002       10:00 -zsh' \\
              ' 7000   200 \(me) ttys002 03-04:05:06 /opt/homebrew/bin/node /very/long/path/to/some/project/scripts/build-and-watch-everything.js --flag' \\
              ' 5151   200 \(me) ttys002       00:42 make verify' \\
              ' 8000     1     0 ttys003       00:10 /usr/sbin/root-tool' \\
              ' 6161     1 \(me) ??     1-00:00:00 /usr/libexec/helper'
            """)
        try fake("lsof", """
            printf 'p4242\\nfcwd\\nn/work/openspot\\np5151\\nfcwd\\nn/work/other\\n'
            """)
        try fake("xcode-select", "exit 1")
        if git {
            try fake("git", """
                [ "$2" = /work/openspot ] && [ "$3 $4" = 'branch --show-current' ] || exit 128
                echo fix-caffeinate
                """)
        }
    }

    private func processRows(in sheet: SpotRun) async throws -> [SpotItem] {
        try await wait("the process row") { self.row("process", in: sheet) != nil }
        guard case .push(_, let route?, _, _)? = try XCTUnwrap(row("process", in: sheet)).move else { throw XCTSkip("the process row opens no page") }
        sheet.show(FlowSheet(spot: sheet.spot.id, route: route))
        try await wait("the processes") { sheet.list.all.count == 3 }
        return sheet.list.all
    }

    func testTheProcessPageGroupsWhatEachTerminalAppStartedWithItsRunTime() async throws {
        try runProcesses()
        let rows = try await processRows(in: try sheet())

        XCTAssertEqual(rows.map(\.title), ["claude · 1h 2m", "make · 42s", "node · 3d 4h"])
        XCTAssertEqual(rows.map(\.section), ["Ghostty", "Terminal", "Terminal"])
    }

    func testARowShowsItsFolderAndItsBranchAndIsFoundByItsCommand() async throws {
        try runProcesses()
        let rows = try await processRows(in: try sheet())

        XCTAssertEqual(rows.prefix(2).map(\.subtitle), ["openspot · fix-caffeinate", "other"])
        XCTAssertEqual(rows.first?.keywords, ["claude --resume abc"])
    }

    func testWithNoGitARowShowsItsFolderAlone() async throws {
        try runProcesses(git: false)
        let rows = try await processRows(in: try sheet())

        XCTAssertEqual(rows.first?.subtitle, "openspot")
    }

    func testARowWithNoFolderShowsItsCommandWithItsStartAndItsEnd() async throws {
        try runProcesses()
        let rows = try await processRows(in: try sheet())

        let detail = try XCTUnwrap(rows.last?.subtitle)
        XCTAssertTrue(detail.hasPrefix("node /very/lo"), detail)
        XCTAssertTrue(detail.hasSuffix(".js --flag"), detail)
        XCTAssertTrue(detail.contains("…"), detail)
        XCTAssertLessThanOrEqual(detail.count, 30, detail)
    }

    func testAPickOfAProcessKeepsTheMacAwakeUntilItEnds() async throws {
        try runProcesses()
        let sheet = try sheet()
        try await wait("the process row") { self.row("process", in: sheet) != nil }
        sheet.show(FlowSheet(spot: sheet.spot.id, route: "processes"))
        try await wait("the processes") { sheet.list.all.count == 3 }

        sheet.pick(try XCTUnwrap(sheet.list.all.first))

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -w 4242"])
        try await wait("the toast") { self.lines("toasts").last == "Caffeinate is on until claude ends" }
        try await wait("the card") { sheet.shownState.subtitle == "Until claude ends" }
    }

    func testAPickOfAProcessThatHasEndedKeepsCaffeinateOffAndSaysSo() async throws {
        try runProcesses()
        let sheet = try sheet()
        try await wait("the process row") { self.row("process", in: sheet) != nil }
        sheet.show(FlowSheet(spot: sheet.spot.id, route: "processes"))
        try await wait("the processes") { sheet.list.all.count == 3 }

        sheet.pick(try XCTUnwrap(sheet.list.all.first { $0.run == "pid.5151" }))

        try await wait("the toast") { self.lines("toasts").last == "That process has ended. Pick one that still runs." }
        XCTAssertTrue(running().isEmpty)
    }

    func testTheCardOfALidHoldSaysTheLidCanClose() async throws {
        let sheet = try await holdWithTheLid()

        try await wait("the card") { sheet.shownState.subtitle == "Until off · lid closed" }
    }

    func testAPickOfTheDisplayRowTurnsItOffAndKeepsItAsASetting() async throws {
        let sheet = try sheet()

        try await pick("display", in: sheet)

        try await wait("the display row off") { self.row("display", in: sheet)?.isOn == false }
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertEqual(setting("display-on"), "false")
        XCTAssertTrue(running().isEmpty)

        try await pick("display", in: sheet)

        try await wait("the display row on") { self.row("display", in: sheet)?.isOn == true }
        XCTAssertEqual(setting("display-on"), "true")
    }

    func testAHoldWithTheDisplayOffLetsTheScreenSleepAndLock() async throws {
        try "false".write(to: folder.appendingPathComponent("setting.display-on"), atomically: true, encoding: .utf8)
        let sheet = try sheet()

        try await pick("1800", in: sheet)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-i -t 1800"])
    }

    func testTheDisplayRowDuringAHoldStartsItAgainWithTheTimeLeft() async throws {
        let sheet = try sheet()
        try await pick("7200", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("display", in: sheet)

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.count == 1 }
        let seconds = try XCTUnwrap(Int(try XCTUnwrap(flags().last?.split(separator: " ").last)))
        XCTAssertEqual(flags().first, "-di -t 7200")
        XCTAssertTrue(flags().last?.hasPrefix("-i -t ") == true)
        XCTAssertTrue((7100...7200).contains(seconds))
        try await wait("the display row off") { self.row("display", in: sheet)?.isOn == false }
    }

    func testAPickOfTheLidRowTurnsItOnAndKeepsItAsASetting() async throws {
        let sheet = try sheet()

        try await pick("lid", in: sheet)

        try await wait("the lid row on") { self.lidRow(in: sheet)?.isOn == true }
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertEqual(lidClosed(), "true")
        XCTAssertTrue(lidRow(in: sheet)?.staysOnPick == true)
        XCTAssertTrue(running().isEmpty)

        try await pick("lid", in: sheet)

        try await wait("the lid row off") { self.lidRow(in: sheet)?.isOn == false }
        XCTAssertEqual(lidClosed(), "false")
    }

    func testTheLidRowDuringAHoldStartsItAgainWithTheTimeLeft() async throws {
        let sheet = try sheet()
        try await pick("7200", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("lid", in: sheet)

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.count == 1 }
        let seconds = try XCTUnwrap(Int(try XCTUnwrap(flags().last?.split(separator: " ").last)))
        XCTAssertEqual(flags().first, "-di -t 7200")
        XCTAssertTrue(flags().last?.hasPrefix("-di -t ") == true)
        XCTAssertTrue((7100...7200).contains(seconds))
        try await wait("the lid held") { self.lidIsHeld() }
        try await wait("the lid row on") { self.lidRow(in: sheet)?.isOn == true }
        XCTAssertEqual(sheet.list.all.first?.run, "off")
        XCTAssertEqual(sheet.list.all.first { $0.title == "2 hours" }?.run.hasPrefix("7200."), true)
    }

    func testAPickKeepsTheMacAwakeInACallThatOutlivesTheSheetAndThePanel() async throws {
        let sheet = try sheet()

        try await pick("1800", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }
        try await wait("the toast") { self.lines("toasts") == ["Caffeinate is on for 30 minutes"] }
        sheet.close()
        runs.panelClosed()

        try await wait("the time left on the card") { sheet.shownState.subtitle == "30m left" }
        XCTAssertEqual(running().count, 1)
        XCTAssertEqual(sheet.calls.map(\.key), ["call:press\n1800"])
        XCTAssertEqual(sheet.list.all.first?.run, "off")
    }

    private func start(in sheet: SpotRun) async throws -> CommandAction {
        try await wait("the button to start") { sheet.spot.frameActions.contains { $0.id == "start" } }
        let start = try XCTUnwrap(sheet.spot.frameActions.first { $0.id == "start" })
        XCTAssertEqual(start.placeholder, "Minutes, such as 45")
        return start
    }

    func testMinutesFromASlashCommandKeepTheMacAwakeAndShowNothing() async throws {
        let sheet = try sheet()
        let start = try await start(in: sheet)

        let answer = try await sheet.launch(start, search: SearchQuery(text: "45", layouts: []))

        XCTAssertEqual(answer, .done)
        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -t 2700"])
        try await wait("the toast") { self.lines("toasts").last == "Caffeinate is on for 45 minutes" }
    }

    func testKeepAwakeForWithNoMinutesAsksWithTheFormOfTheSpot() async throws {
        let sheet = try sheet()
        let start = try await start(in: sheet)

        let answer = try await sheet.launch(start, search: SearchQuery(text: "", layouts: []))

        guard case .form(let form) = answer else { return XCTFail("no form: \(answer)") }
        XCTAssertEqual(form.title, "Keep the Mac awake")
        XCTAssertEqual(form.fields.map(\.label), ["Minutes"])
        XCTAssertTrue(running().isEmpty)
    }

    func testTextThatIsNoNumberShowsAnErrorAndTheDurations() async throws {
        let sheet = try sheet()
        let start = try await start(in: sheet)

        let answer = try await sheet.launch(start, search: SearchQuery(text: "soon", layouts: []))

        XCTAssertEqual(answer, .shown)
        try await wait("the toast") { self.lines("toasts").last == "Caffeinate takes minutes as a number, such as 45." }
        XCTAssertTrue(running().isEmpty)
    }

    func testTurnOffEndsCaffeinateAndItsCall() async throws {
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("off", in: sheet)

        try await wait("the end of caffeinate") { self.running().isEmpty }
        try await wait("the end of the calls") { sheet.calls.isEmpty }
        try await wait("the rows without Turn off") { sheet.list.all.first?.run == "1800" }
        XCTAssertEqual(lines("toasts").last, "Caffeinate is off")
        XCTAssertEqual(sheet.shownState.subtitle, "Keep the Mac awake")
    }

    func testAnotherDurationReplacesTheOneThatRuns() async throws {
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("7200", in: sheet)

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.map(\.key) == ["call:press\n7200"] }
        XCTAssertEqual(running(), [awake()[1]])
    }

    func testAPickOfTheDurationThatRunsStartsItAgain() async throws {
        let sheet = try sheet()
        try await pick("7200", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }
        try await wait("the rows with Turn off") { sheet.list.all.first?.run == "off" }

        sheet.pick(try XCTUnwrap(sheet.list.all.first { $0.title == "2 hours" }))

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.count == 1 }
        try await wait("the toast again") { self.lines("toasts") == ["Caffeinate is on for 2 hours", "Caffeinate is on for 2 hours"] }
        XCTAssertEqual(running(), [awake()[1]])
    }

    func testATimeThatEndsByItselfEndsTheCallAndShowsOff() async throws {
        touch("short")
        let sheet = try sheet()

        try await pick("1800", in: sheet)

        try await wait("the end of the call") { !self.awake().isEmpty && sheet.calls.isEmpty }
        try await wait("the rows without Turn off") { sheet.list.all.first?.run == "1800" }
        XCTAssertEqual(sheet.shownState.subtitle, "Keep the Mac awake")
        XCTAssertEqual(running(), [])
    }

    func testAQuitOfOpenspotLeavesNoProcessOfTheSpot() async throws {
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        runs.quit()

        try await wait("the end of caffeinate") { self.running().isEmpty }
    }

    func testTheLidRowAsksTheMacForNothingUntilAHold() async throws {
        let sheet = try sheet()

        try await pick("lid", in: sheet)

        try await wait("the lid row on") { self.lidRow(in: sheet)?.isOn == true }
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertEqual(lines("lid"), [])
    }

    private func holdWithTheLid() async throws -> SpotRun {
        try keepLidClosed()
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("the lid held") { self.lidIsHeld() }
        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di"])
        return sheet
    }

    func testAHoldWithTheLidHoldsItAndTurnOffLetsItGo() async throws {
        let sheet = try await holdWithTheLid()

        try await pick("off", in: sheet)

        try await wait("the lid let go") { self.lidIsLetGo() }
        XCTAssertEqual(lines("lid").last?.hasSuffix(" off"), true)
    }

    func testAQuitOfOpenspotLetsTheLidGo() async throws {
        _ = try await holdWithTheLid()

        runs.quit()

        try await wait("the lid let go") { self.lidIsLetGo() }
    }

    func testATimeThatEndsByItselfLetsTheLidGo() async throws {
        touch("short")

        _ = try await holdWithTheLid()

        try await wait("the lid let go") { self.lidIsLetGo() }
    }

    func testAHoldThatTheMacRefusesKeepsTheScreenOnTurnsTheLidOffAndSaysWhy() async throws {
        touch("deny")
        try keepLidClosed()
        let sheet = try sheet()

        try await pick("1800", in: sheet)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -t 1800"])
        try await wait("the toast") { self.lines("toasts").last == "Caffeinate is on for 30 minutes, but not with the lid closed. \(Self.approval)" }
        try await wait("the lid row off") { self.lidRow(in: sheet)?.isOn == false }
        XCTAssertEqual(lidClosed(), "false")
    }
}
