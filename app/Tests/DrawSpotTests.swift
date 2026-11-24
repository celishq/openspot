import Darwin
import XCTest
@testable import OpenspotCore

@MainActor
final class DrawSpotTests: XCTestCase {
    private static let buildLimit: Double = 900
    private static let bad = Data(#"{"title":"Plan","figures":"none"}"#.utf8)

    private var runs: SpotRuns!
    private var started: [SpotRuns] = []
    private var home: URL!
    private var boards: URL!
    private var toasts: [String] = []
    private var records: [CallLog.Record] = []

    override func setUp() async throws {
        home = try temporaryFolder()
        boards = home.appendingPathComponent(".config/openspot/data/draw/boards")
        try FileManager.default.createDirectory(at: boards, withIntermediateDirectories: true)
        try "#!/bin/sh\necho \"$1\" > '\(home.path)/opened'\n".writeScript(to: home.appendingPathComponent("tools/open"))
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: home.appendingPathComponent("tools/openspot"))
    }

    override func tearDown() async throws {
        started.forEach { $0.quit() }
        started = []
        runs = nil
    }

    private var environment: [String: String] {
        ProcessInfo.processInfo.environment.merging([
            "HOME": home.path,
            "PATH": "\(home.path)/tools:/usr/bin:/bin",
            "OPENSPOT_CONFIG": home.appendingPathComponent(".config/openspot").path
        ]) { _, new in new }
    }

    private func draw() throws -> Spot {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
        return try XCTUnwrap(try SpotsFolder(url: spots).scan().spots.first { $0.id == "draw" })
    }

    private func write(_ title: String, id: String, age: TimeInterval = 60) throws {
        let file = boards.appendingPathComponent("\(id).json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"figures":[{"id":"4C9C8A4E-7F0B-4A53-9A3B-0B6E7C2D1F10","ink":"black","kind":"shape","form":"rectangle","points":[[0,0],[10,10]],"weight":"m","align":"center","place":"middle"}],"title":"\#(title)"}"#.utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: file.path)
    }

    private func figures(of file: URL) throws -> Int {
        let board = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        return (board["figures"] as? [Any])?.count ?? 0
    }

    private func shownFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: boards.path).filter { !$0.hasPrefix(".") }.sorted()
    }

    private func title(of file: URL) throws -> String? {
        (try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])?["title"] as? String
    }

    private func opened(_ spot: Spot) async throws -> SpotRun {
        runs = SpotRuns(environment: environment, showLimit: 120, stopPause: 20)
        started.append(runs)
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": home.appendingPathComponent(".config/openspot").path]), app: FakeRunningApp(), runs: runs)
        let count = records.count
        runs.onCall = { [unowned self] record in records.append(record) }
        let sheet = runs.sheet(for: spot)
        sheet.onReport = { [unowned self] report in
            if case .toast(let note) = report { toasts.append(note.words) }
        }
        runs.panelOpened()
        sheet.open {}
        try await wait("the sheet of Draw, which Openspot builds first", seconds: Self.buildLimit) { !sheet.list.shown.isEmpty }
        sheet.run(CommandAction(id: "windowless", title: "No window"), item: nil)
        try await wait("the end of the call that tells Draw to show no window") { self.records.dropFirst(count).contains { $0.arguments == ["windowless"] } }
        return sheet
    }

    private func row(_ name: String, in sheet: SpotRun) throws -> SpotItem {
        try XCTUnwrap(sheet.list.shown.first { $0.run.hasSuffix(":\(name)") })
    }

    private func program(of spot: Spot) async throws -> String {
        let built = try await SwiftProgram().built(spot.url, with: spot.sources)
        return built.resolvingSymlinksInPath().path
    }

    private func processes(of program: String) -> [pid_t] {
        var ids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&ids, Int32(ids.count * MemoryLayout<pid_t>.size)))
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        return ids.prefix(max(count, 0)).filter { id in
            let length = proc_pidpath(id, &buffer, UInt32(buffer.count))
            return length > 0 && URL(fileURLWithPath: String(decoding: buffer[..<Int(length)], as: UTF8.self)).resolvingSymlinksInPath().path == program
        }
    }

    private func ended(_ arguments: [String]) -> Bool {
        let item = arguments.dropFirst().first.map { "input.item=\($0)" }
        return records.contains { record in record.arguments == [arguments[0]] && item.map { (record.input ?? "").contains($0) } ?? true }
    }

    func testTheSheetListsANewBoardThenEachBoardNewestFirst() async throws {
        let spot = try draw()
        try write("Old plan", id: "old", age: 7200)
        try write("Flows", id: "flows", age: 120)
        try write("Plan", id: "Work/plan", age: 60)

        let rows = try await opened(spot).list.shown

        XCTAssertEqual(rows.map(\.title), ["New board", "Plan", "Flows", "Old plan"])
        XCTAssertEqual(rows.map(\.run), ["0:new", "0:Work/plan", "0:flows", "0:old"])
        XCTAssertEqual(rows.map(\.subtitle), ["A blank board", "Work · Edited 1 min ago", "Edited 2 min ago", "Edited 2 h ago"])
        XCTAssertTrue(spot.hasSheet)
        XCTAssertNotEqual(spot.triggers.searchesSheet, true)
    }

    func testARenameKeepsTheFiguresAndChangesTheTitle() async throws {
        let spot = try draw()
        try write("Untitled board", id: "a")
        let sheet = try await opened(spot)
        let item = try row("a", in: sheet)
        let rename = try XCTUnwrap(sheet.spot.frameActions.first { $0.id == "rename" })
        guard case .form(let form) = await sheet.answer(to: rename, item: item) else { return XCTFail("Rename asked with no form") }
        var draft = FormDraft(form: form)
        XCTAssertEqual(draft.form.fields.map(\.value), ["Untitled board"])
        draft.set("Launch flow", for: "name")

        _ = try await sheet.submit(rename, item: item, draft: draft)

        try await wait("the new title in the sheet") { sheet.list.shown.contains { $0.title == "Launch flow" } }
        XCTAssertEqual(try title(of: boards.appendingPathComponent("a.json")), "Launch flow")
        XCTAssertEqual(try figures(of: boards.appendingPathComponent("a.json")), 1)
        XCTAssertEqual(sheet.selectedItem?.run, item.run)
    }

    func testADeleteMovesTheBoardToTheTrashAndTakesItOffTheSheet() async throws {
        let spot = try draw()
        try write("Flows", id: "flows")
        try Data().write(to: boards.appendingPathComponent("flows.png"))
        let sheet = try await opened(spot)

        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first { $0.id == "delete" }), item: try row("flows", in: sheet))

        try await wait("the sheet with no board") { sheet.list.shown.map(\.title) == ["New board"] }
        XCTAssertEqual(toasts, ["Moved Flows to the Trash."])
        XCTAssertEqual(try shownFiles(), [])
        let trash = try FileManager.default.contentsOfDirectory(atPath: home.appendingPathComponent(".Trash").path).sorted()
        XCTAssertEqual(trash.count, 2)
        XCTAssertTrue(trash[0].hasPrefix("Flows-") && trash[0].hasSuffix(".json"))
        XCTAssertTrue(trash[1].hasPrefix("Flows-") && trash[1].hasSuffix(".png"))
    }

    func testShowBoardsInFinderOpensTheFolderOfTheBoards() async throws {
        let spot = try draw()
        let sheet = try await opened(spot)

        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first { $0.id == "reveal" }), item: nil)

        try await wait("the folder that Finder got") { FileManager.default.fileExists(atPath: home.appendingPathComponent("opened").path) }
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent("opened"), encoding: .utf8).trimmingCharacters(in: .newlines), boards.path)
    }

    func testOpeningAGoneBoardSaysSoAndHoldsNoCall() async throws {
        let spot = try draw()
        let sheet = try await opened(spot)

        sheet.pick(SpotItem(title: "Gone", run: "0:gone"))

        try await wait("the toast") { !self.toasts.isEmpty }
        XCTAssertEqual(toasts, ["This board is gone."])
        try await wait("the end of the call") { self.ended(["press", "0:gone"]) }
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testABoardThatFailsToLoadIsNotOpenedAndItsFileStaysAsItWas() async throws {
        let spot = try draw()
        let file = boards.appendingPathComponent("plan.json")
        try Self.bad.write(to: file)
        let sheet = try await opened(spot)
        XCTAssertEqual(sheet.list.shown.map(\.title), ["New board", "Plan"])

        sheet.pick(try row("plan", in: sheet))

        try await wait("the end of the call") { self.ended(["press", "0:plan"]) }
        XCTAssertEqual(toasts, ["Draw cannot read this board. Its file stays as it is."])
        XCTAssertTrue(sheet.calls.isEmpty)
        runs.quit()
        let program = try await program(of: spot)
        try await wait("the end of Draw") { self.processes(of: program).isEmpty }
        XCTAssertEqual(try Data(contentsOf: file), Self.bad)
    }

    func testTheStudioLivesWhileItsCallWaitsAndASecondOpenReachesTheSameProcess() async throws {
        let spot = try draw()
        try write("Flows", id: "flows", age: 120)
        try write("Plan", id: "plan", age: 60)
        let sheet = try await opened(spot)
        let program = try await program(of: spot)
        let first = processes(of: program)
        XCTAssertEqual(first.count, 1)

        sheet.pick(try row("flows", in: sheet))
        try await wait("the rows of the next turn, which the call that waits prints") { sheet.list.shown.first?.run == "1:new" }
        let held = try XCTUnwrap(sheet.calls.first)
        sheet.close()
        runs.panelClosed()
        XCTAssertTrue(sheet.isWanted)

        runs.panelOpened()
        sheet.open {}
        sheet.pick(try row("plan", in: sheet))
        try await wait("the end of the second open") { self.ended(["press", "1:plan"]) }
        XCTAssertEqual(sheet.calls.map(\.id), [held.id])
        XCTAssertEqual(processes(of: program), first)
        XCTAssertTrue(sheet.acts.isEmpty)

        sheet.pick(SpotItem(title: "New board", run: "1:new"))
        try await wait("the end of the new board's call") { self.ended(["press", "1:new"]) }
        XCTAssertEqual(sheet.calls.map(\.id), [held.id])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: boards.path).filter { $0.hasSuffix(".json") }.count, 3)

        sheet.close()
        runs.panelClosed()
        sheet.stop(held)

        try await wait("the end of Draw") { self.processes(of: program).isEmpty }
        XCTAssertTrue(sheet.calls.isEmpty)
        XCTAssertFalse(sheet.isWanted)
        XCTAssertEqual(try figures(of: boards.appendingPathComponent("flows.json")), 1)
    }

    func testAQuitOfOpenspotLeavesNoProcessOfDraw() async throws {
        let spot = try draw()
        try write("Flows", id: "flows")
        let sheet = try await opened(spot)
        let program = try await program(of: spot)
        sheet.pick(try row("flows", in: sheet))
        try await wait("the call that waits") { sheet.list.shown.first?.run == "1:new" }
        sheet.close()
        runs.panelClosed()
        XCTAssertEqual(processes(of: program).count, 1)

        runs.quit()

        try await wait("the end of Draw") { self.processes(of: program).isEmpty }
        XCTAssertEqual(try shownFiles(), ["flows.json"])
    }

    func testDrawEndsWhenItsSheetClosesWithNoBoardOpen() async throws {
        let spot = try draw()
        let sheet = try await opened(spot)
        let program = try await program(of: spot)
        XCTAssertEqual(processes(of: program).count, 1)

        sheet.close()
        runs.panelClosed()

        try await wait("the end of Draw") { self.processes(of: program).isEmpty }
    }

    func testASecondOpenspotChangesNoBoardWhileTheFirstHasOneOpenAndSaysSo() async throws {
        let spot = try draw()
        try write("Flows", id: "flows")
        let file = boards.appendingPathComponent("flows.json")
        let first = try await opened(spot)
        first.pick(try row("flows", in: first))
        try await wait("the call that waits") { first.list.shown.first?.run == "1:new" }
        let program = try await program(of: spot)
        let second = try await opened(spot)
        XCTAssertEqual(processes(of: program).count, 2)
        let item = try row("flows", in: second)
        let rename = try XCTUnwrap(second.spot.frameActions.first { $0.id == "rename" })
        guard case .form(let form) = await second.answer(to: rename, item: item) else { return XCTFail("Rename asked with no form") }
        var draft = FormDraft(form: form)
        draft.set("Other", for: "name")

        _ = try await second.submit(rename, item: item, draft: draft)
        try await wait("the toast of the rename") { self.toasts.count == 1 }
        second.pick(item)
        try await wait("the toast of the open") { self.toasts.count == 2 }
        second.pick(SpotItem(title: "New board", run: "0:new"))
        try await wait("the toast of the new board") { self.toasts.count == 3 }

        XCTAssertEqual(Set(toasts), ["Another Draw has these boards open, so nothing changed. Close it, then try again."])
        XCTAssertEqual(try title(of: file), "Flows")
        XCTAssertEqual(try shownFiles(), ["flows.json"])
        try await wait("the end of the second open") { self.ended(["press", "0:new"]) }
        XCTAssertTrue(second.calls.isEmpty)
    }

    func testTheCallThatOpensTheStudioKeepsDrawWantedAndShowsNoWork() async throws {
        let clock = FakeClock()
        let link = FakeMode()
        runs = SpotRuns(clock: clock.value)
        runs.standIn = { _ in link }
        let sheet = runs.sheet(for: try draw())
        runs.panelOpened()
        sheet.open {}
        await link.frame("frame=\nrecents=false\n\nitem=0:new\ntitle=New board\n\nitem=0:flows\ntitle=Flows\n", of: link.sent[0])
        await link.end(link.sent[0])

        sheet.pick(try row("flows", in: sheet))
        let held = try XCTUnwrap(link.sent.last)
        XCTAssertEqual(SpotRun.item(of: held.request.message), "0:flows")
        await link.frame("call=2\n\nitem=1:new\ntitle=New board\n\nitem=1:flows\ntitle=Flows\n", of: held)
        sheet.close()
        runs.panelClosed()
        try await wait("the sleep of the work that shows after a second") { clock.sleepCount > 0 }
        clock.advance(by: 5)

        XCTAssertTrue(sheet.isWanted)
        XCTAssertEqual(sheet.calls.map(\.id), [held.made.id])

        sheet.pick(try row("flows", in: sheet))
        XCTAssertEqual(link.sent.last.flatMap { SpotRun.item(of: $0.request.message) }, "1:flows")
        XCTAssertFalse(held.made.isStopped)
        await link.end(try XCTUnwrap(link.sent.last))
        for read in link.sent.dropFirst() where read.request.handler == ScriptEntry.show.name { await link.end(read) }
        XCTAssertEqual(sheet.calls.map(\.id), [held.made.id])
        XCTAssertTrue(sheet.isWanted)
        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertNil(runs.runningSummary)

        await link.end(held)
        for read in link.sent.dropFirst() where read.request.handler == ScriptEntry.show.name && sheet.calls.contains(where: { $0 === read.made }) { await link.end(read) }
        XCTAssertFalse(sheet.isWanted)
    }
}
