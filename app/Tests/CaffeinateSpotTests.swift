import XCTest
@testable import OpenspotCore

@MainActor
final class CaffeinateSpotTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var toasts: [String] = []

    override func setUp() async throws {
        folder = try temporaryFolder()
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\necho \"$$ $*\" >> '\(folder.path)/awake'\n[ -f '\(folder.path)/short' ] && exec /bin/sleep 0.3\nexec /bin/sleep 600\n".writeScript(to: tools.appendingPathComponent("caffeinate"))
        try "#!/bin/sh\ncase \"$1 $2\" in\n'setting get') cat '\(folder.path)/lid' 2>/dev/null ;;\n'setting set') printf %s \"$4\" > '\(folder.path)/lid' ;;\nesac\n".writeScript(to: tools.appendingPathComponent("openspot"))
        runs = SpotRuns(environment: ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path, "TMPDIR": folder.path + "/"], stopPause: 0.2)
    }

    override func tearDown() async throws {
        runs.quit()
        for pid in awake() { kill(pid, SIGKILL) }
    }

    private func sheet() throws -> SpotRun {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let spot = try XCTUnwrap(try SpotsFolder(url: root.appendingPathComponent("spots")).scan().spots.first { $0.id == "caffeinate" })
        let sheet = runs.sheet(for: spot)
        sheet.onReport = { [weak self] in if case .toast(let text) = $0 { self?.toasts.append(text) } }
        runs.panelOpened()
        sheet.open {}
        return sheet
    }

    private func awake() -> [pid_t] {
        let text = (try? String(contentsOf: folder.appendingPathComponent("awake"), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").compactMap { $0.split(separator: " ").first.flatMap { pid_t($0) } }
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
    }

    private func lid() -> String? {
        try? String(contentsOf: folder.appendingPathComponent("lid"), encoding: .utf8)
    }

    private func flags() -> [String] {
        let text = (try? String(contentsOf: folder.appendingPathComponent("awake"), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map { $0.split(separator: " ").dropFirst().joined(separator: " ") }
    }

    func testAPickOfTheLidRowTurnsItOnAndKeepsItAsASetting() async throws {
        let sheet = try sheet()

        try await pick("lid", in: sheet)

        try await wait("the lid row on") { sheet.list.all.first { $0.run == "lid" }?.isOn == true }
        XCTAssertEqual(lid(), "true")
        XCTAssertTrue(sheet.list.all.first { $0.run == "lid" }?.staysOnPick == true)
        XCTAssertTrue(running().isEmpty)

        try await pick("lid", in: sheet)

        try await wait("the lid row off") { sheet.list.all.first { $0.run == "lid" }?.isOn == false }
        XCTAssertEqual(lid(), "false")
    }

    func testAHoldWithTheLidOnLetsTheScreenLock() async throws {
        try "true".write(to: folder.appendingPathComponent("lid"), atomically: true, encoding: .utf8)
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
        try await wait("the lid row on") { sheet.list.all.first { $0.run == "lid" }?.isOn == true }
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
        XCTAssertTrue(try String(contentsOf: folder.appendingPathComponent("awake"), encoding: .utf8).contains("-di -t 2700"))
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
        FileManager.default.createFile(atPath: folder.appendingPathComponent("short").path, contents: Data())
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
}
