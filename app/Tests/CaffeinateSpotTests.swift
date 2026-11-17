import XCTest
@testable import OpenspotCore

@MainActor
final class CaffeinateSpotTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var toasts: [String] = []
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
              'setting get') cat "\(f)/setting.$3" 2>/dev/null ;;
              'setting set') printf %s "$4" > "\(f)/setting.$3" ;;
            esac
            """)
        try fake("sudo", """
            echo "$*" >> '\(f)/sudo'
            [ -f '\(f)/rule' ]
            """)
        try fake("osascript", """
            echo "$*" >> '\(f)/osascript'
            [ ! -f '\(f)/deny' ] && : > '\(f)/rule'
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
        sheet.list.all.first { $0.run == "lid" }
    }

    private func sleepIsOn() -> Bool {
        lines("sudo").last == "-n /usr/bin/pmset disablesleep 0"
    }

    private func sleepIsOff() -> Bool {
        lines("sudo").last == "-n /usr/bin/pmset disablesleep 1"
    }

    override func tearDown() async throws {
        runs.quit()
        for pid in awake() { kill(pid, SIGKILL) }
    }

    private func spot() throws -> Spot {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try XCTUnwrap(try SpotsFolder(url: root.appendingPathComponent("spots")).scan().spots.first { $0.id == "caffeinate" })
    }

    private func mark() throws -> URL {
        ScriptProcess.dataFolder(base: environment, dataName: try spot().dataName).appendingPathComponent("sleep-off")
    }

    private func lines(_ name: String) -> [String] {
        let text = (try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    private func sheet() throws -> SpotRun {
        let spot = try spot()
        let sheet = runs.sheet(for: spot)
        sheet.onReport = { [weak self] in if case .toast(let text) = $0 { self?.toasts.append(text) } }
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
        XCTAssertEqual(sheet.list.all.map(\.run), ["1800", "3600", "7200", "14400", "28800", "0", "lid"])
        XCTAssertEqual(sheet.list.all.map(\.title), ["30 minutes", "1 hour", "2 hours", "4 hours", "8 hours", "Until turned off", "Work with the lid closed"])
        XCTAssertEqual(sheet.list.all.last?.isOn, false)
        XCTAssertEqual(sheet.list.all.last?.isToggle, true)
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

    func testAHoldWithTheLidOnLetsTheScreenLock() async throws {
        touch("rule")
        try keepLidClosed()
        let sheet = try sheet()

        try await pick("1800", in: sheet)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-i -t 1800"])
    }

    func testTheLidRowDuringAHoldStartsItAgainWithTheTimeLeft() async throws {
        let sheet = try sheet()
        try await pick("3600", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("lid", in: sheet)

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.count == 1 }
        let seconds = try XCTUnwrap(Int(try XCTUnwrap(flags().last?.split(separator: " ").last)))
        XCTAssertEqual(flags().first, "-di -t 3600")
        XCTAssertTrue(flags().last?.hasPrefix("-i -t ") == true)
        XCTAssertTrue((3500...3600).contains(seconds))
        try await wait("the lid row on") { self.lidRow(in: sheet)?.isOn == true }
        XCTAssertEqual(sheet.list.all.first?.run, "off")
        XCTAssertEqual(sheet.list.all.first { $0.title == "1 hour" }?.run.hasPrefix("3600."), true)
    }

    func testAPickKeepsTheMacAwakeInACallThatOutlivesTheSheetAndThePanel() async throws {
        let sheet = try sheet()

        try await pick("1800", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }
        try await wait("the toast") { self.toasts == ["Caffeinate is on for 30 minutes"] }
        sheet.close()
        runs.panelClosed()

        try await wait("the time left on the card") { sheet.shownState.subtitle == "30m left" }
        XCTAssertEqual(running().count, 1)
        XCTAssertEqual(sheet.calls.map(\.action.arguments), [["open", "1800"]])
        XCTAssertEqual(sheet.list.all.first?.run, "off")
    }

    private func start(in sheet: SpotRun) async throws -> CommandAction {
        try await wait("the button to start") { sheet.spot.actions.contains { $0.id == "start" } }
        let start = try XCTUnwrap(sheet.spot.actions.first { $0.id == "start" })
        XCTAssertEqual(start.placeholder, "Minutes, such as 45")
        return start
    }

    func testMinutesFromASlashCommandKeepTheMacAwakeAndShowNothing() async throws {
        let sheet = try sheet()
        let start = try await start(in: sheet)

        let answer = try await sheet.launch(start, input: "search=45\n")

        XCTAssertEqual(answer, .done)
        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -t 2700"])
        try await wait("the toast") { self.toasts.last == "Caffeinate is on for 45 minutes" }
    }

    func testTextThatIsNoNumberShowsAnErrorAndTheDurations() async throws {
        let sheet = try sheet()
        let start = try await start(in: sheet)

        let answer = try await sheet.launch(start, input: "search=soon\n")

        XCTAssertEqual(answer, .shown)
        try await wait("the toast") { self.toasts.last == "Caffeinate takes minutes as a number, such as 45." }
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
        XCTAssertEqual(toasts.last, "Caffeinate is off")
        XCTAssertEqual(sheet.shownState.subtitle, "Keep the Mac awake")
    }

    func testAnotherDurationReplacesTheOneThatRuns() async throws {
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }

        try await pick("3600", in: sheet)

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.map(\.action.arguments) == [["open", "3600"]] }
        XCTAssertEqual(running(), [awake()[1]])
    }

    func testAPickOfTheDurationThatRunsStartsItAgain() async throws {
        let sheet = try sheet()
        try await pick("3600", in: sheet)
        try await wait("caffeinate") { self.running().count == 1 }
        try await wait("the rows with Turn off") { sheet.list.all.first?.run == "off" }

        sheet.pick(try XCTUnwrap(sheet.list.all.first { $0.title == "1 hour" }))

        try await wait("one new caffeinate") { self.awake().count == 2 && self.running().count == 1 }
        try await wait("the one call") { sheet.calls.count == 1 }
        try await wait("the toast again") { self.toasts == ["Caffeinate is on for 1 hour", "Caffeinate is on for 1 hour"] }
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

    func testTheLidRowAsksOnceForThePasswordToInstallTheRule() async throws {
        let sheet = try sheet()

        try await pick("lid", in: sheet)

        try await wait("the lid row on") { self.lidRow(in: sheet)?.isOn == true }
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertEqual(lines("osascript").count, 1)
        XCTAssertTrue(lines("osascript")[0].contains("with administrator privileges"))
        XCTAssertTrue(lines("osascript")[0].contains("ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0' > /etc/sudoers.d/openspot-caffeinate"))
        XCTAssertTrue(lines("osascript")[0].contains("/usr/sbin/visudo -c -f /etc/sudoers.d/openspot-caffeinate"))

        try await pick("lid", in: sheet)
        try await wait("the lid row off") { self.lidRow(in: sheet)?.isOn == false }
        try await wait("the end of the call") { sheet.calls.isEmpty }
        try await pick("lid", in: sheet)

        try await wait("the lid row on again") { self.lidRow(in: sheet)?.isOn == true }
        XCTAssertEqual(lines("osascript").count, 1)
    }

    func testADeniedPasswordLeavesTheLidOff() async throws {
        touch("deny")
        let sheet = try sheet()

        try await pick("lid", in: sheet)

        try await wait("the toast") { self.toasts.last == "Caffeinate works with the lid closed only with your password. Pick the row again to enter it." }
        XCTAssertEqual(lidRow(in: sheet)?.isOn, false)
        XCTAssertNotEqual(lidClosed(), "true")
    }

    private func holdWithTheLid() async throws -> SpotRun {
        touch("rule")
        try keepLidClosed()
        let sheet = try sheet()
        try await pick("0", in: sheet)
        try await wait("sleep off") { self.sleepIsOff() }
        XCTAssertTrue(FileManager.default.fileExists(atPath: try mark().path))
        return sheet
    }

    func testAHoldWithTheLidTurnsSleepOffAndTurnOffTurnsItOn() async throws {
        let sheet = try await holdWithTheLid()

        try await pick("off", in: sheet)

        try await wait("sleep on") { self.sleepIsOn() }
        let mark = try mark()
        try await wait("the mark gone") { !FileManager.default.fileExists(atPath: mark.path) }
    }

    func testAQuitOfOpenspotTurnsSleepOnAgain() async throws {
        _ = try await holdWithTheLid()

        runs.quit()

        try await wait("sleep on") { self.sleepIsOn() }
    }

    func testATimeThatEndsByItselfTurnsSleepOnAgain() async throws {
        touch("short")

        _ = try await holdWithTheLid()

        try await wait("sleep on") { self.sleepIsOn() }
    }

    func testAMarkLeftByACrashTurnsSleepOnAtTheNextStart() async throws {
        touch("rule")
        try FileManager.default.createDirectory(at: try mark().deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: try mark().path, contents: Data())

        _ = try sheet()

        try await wait("sleep on") { self.lines("sudo") == ["-n /usr/bin/pmset disablesleep 0"] }
        let mark = try mark()
        try await wait("the mark gone") { !FileManager.default.fileExists(atPath: mark.path) }
    }

    func testAHoldWithTheLidAfterTheRuleIsGoneKeepsTheScreenOnAndTurnsTheLidOff() async throws {
        try keepLidClosed()
        let sheet = try sheet()

        try await pick("1800", in: sheet)

        try await wait("caffeinate") { self.running().count == 1 }
        XCTAssertEqual(flags(), ["-di -t 1800"])
        try await wait("the toast") { self.toasts.last == "Caffeinate is on for 30 minutes, but not with the lid closed. Pick Work with the lid closed to enter your password again." }
        try await wait("the lid row off") { self.lidRow(in: sheet)?.isOn == false }
        XCTAssertEqual(lidClosed(), "false")
    }
}
