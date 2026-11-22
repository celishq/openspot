import XCTest

final class DrawSheetTests: XCTestCase {
    private var folder: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = try emptyFolder()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func board(_ name: String, title: String, age: TimeInterval) throws {
        let file = folder.appendingPathComponent("\(name).json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Board(title: title).save(to: file)
        try self.age(file, by: age, from: now)
    }

    private func rows(_ frame: String) -> [[String]] {
        frame.components(separatedBy: "\n\n").map { $0.split(separator: "\n").map(String.init) }.filter { $0.first?.hasPrefix("item=") == true }
    }

    func testTheSheetListsANewBoardThenEachBoardNewestFirst() throws {
        try board("old", title: "Old plan", age: 7200)
        try board("flows", title: "Flows", age: 120)
        try board("fresh", title: "Fresh", age: 5)
        try board("last-year", title: "Last year", age: 400 * 86400)

        let rows = rows(Sheet(shelf: Shelf(folder: folder), now: now).frame())

        XCTAssertEqual(rows.map { $0[0] }, ["item=0:new", "item=0:fresh", "item=0:flows", "item=0:old", "item=0:last-year"])
        XCTAssertEqual(rows.map { $0[1] }, ["title=New board", "title=Fresh", "title=Flows", "title=Old plan", "title=Last year"])
        XCTAssertEqual(rows.map { $0[2] }, ["detail=A blank board", "detail=Edited just now", "detail=Edited 2 min ago", "detail=Edited 2 h ago", "detail=Edited Dec 11"])
        XCTAssertEqual(rows[0].suffix(2), ["hides=rename", "hides=delete"])
    }

    func testTheSheetListsEveryBoardHoweverMany() throws {
        for index in 1...12 { try board("b\(index)", title: "Board \(index)", age: TimeInterval(index * 60)) }

        XCTAssertEqual(rows(Sheet(shelf: Shelf(folder: folder), now: now).frame()).count, 13)
    }

    func testABoardInAFolderIsNamedWithItsFolderAndShowsItsPicture() throws {
        try board("Work/plan", title: "Plan", age: 60)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Work/plan.assets"), withIntermediateDirectories: true)
        let picture = folder.appendingPathComponent("Work/plan.png")
        try Data().write(to: picture)
        let sheet = Sheet(shelf: Shelf(folder: folder), now: now)

        let rows = rows(sheet.frame())

        XCTAssertEqual(rows.map { $0[0] }, ["item=0:new", "item=0:Work/plan"])
        XCTAssertEqual(rows[1][2], "detail=Work · Edited 1 min ago")
        XCTAssertEqual(URL(fileURLWithPath: String(rows[1][3].dropFirst(5))).resolvingSymlinksInPath().path, picture.resolvingSymlinksInPath().path)
        XCTAssertEqual(sheet.file(named: "Work/plan")?.lastPathComponent, "plan.json")
    }

    func testATitleOfTwoLinesStaysOneLineOfTheFrame() throws {
        try board("two", title: "Two\nlines", age: 60)

        XCTAssertEqual(rows(Sheet(shelf: Shelf(folder: folder), now: now).frame())[1][1], #"title=Two\nlines"#)
    }

    func testTheHeadOfTheFrameHoldsTheLinesOfTheCall() {
        let frame = Sheet(shelf: Shelf(folder: folder), now: now).frame(head: ["end=4", "call=5"])

        XCTAssertTrue(frame.hasPrefix("frame=\nrecents=false\nend=4\ncall=5\n\nbutton=open\n"))
    }

    func testEachTurnGivesTheRowsAndTheNewButtonOtherIDsAndTheSameNames() throws {
        try board("flows", title: "Flows", age: 60)
        let shelf = Shelf(folder: folder)

        let first = Sheet(shelf: shelf, turn: 0, now: now).frame()
        let second = Sheet(shelf: shelf, turn: 1, now: now).frame()

        XCTAssertTrue(first.contains("button=0:new\n"))
        XCTAssertTrue(second.contains("button=1:new\n"))
        XCTAssertEqual(rows(second).map { $0[0] }, ["item=1:new", "item=1:flows"])
        XCTAssertEqual(Sheet.name(in: "1:flows"), "flows")
        XCTAssertEqual(Sheet.name(in: "12:Work/a:b"), "Work/a:b")
        XCTAssertEqual(Sheet.name(in: "rename"), "rename")
        XCTAssertEqual(Sheet.name(in: "a:b"), "a:b")
    }

    func testARowNamesOnlyABoardInsideTheFolderOfTheBoards() throws {
        try board("flows", title: "Flows", age: 60)
        let sheet = Sheet(shelf: Shelf(folder: folder), now: now)

        XCTAssertNotNil(sheet.file(named: "flows"))
        XCTAssertNil(sheet.file(named: "gone"))
        XCTAssertNil(sheet.file(named: "../flows"))
        XCTAssertNil(sheet.file(named: "/etc/hosts"))
        XCTAssertNil(sheet.file(named: ""))
    }

    func testTheRenameFormHoldsTheTitleOfTheBoard() {
        XCTAssertEqual(Sheet.renameForm(title: "Flows", head: ["end=3"]), "frame=\ntype=form\nend=3\ntitle=Rename board\n\nfield=name\ntitle=Name\nvalue=Flows\nrequired=true\n")
    }

    func testTheSampleIsTheSheetOverSampleBoards() throws {
        try board("flows", title: "Sign-up flow", age: 180)
        try board("launch", title: "Launch plan", age: 3 * 3600)
        try board("Work/roadmap", title: "Roadmap", age: 26 * 3600)
        let spot = try XCTUnwrap(ProcessInfo.processInfo.environment["DRAW_SPOT"])
        let sample = Process()
        sample.executableURL = URL(fileURLWithPath: "/bin/sh")
        sample.arguments = [spot + "/sample.sh"]
        let output = Pipe()
        sample.standardOutput = output
        try sample.run()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        sample.waitUntilExit()

        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "MMM d"
        let frame = Sheet(shelf: Shelf(folder: folder), now: now).frame().replacingOccurrences(of: "Edited \(day.string(from: now.addingTimeInterval(-26 * 3600)))", with: "Edited yesterday")

        XCTAssertEqual(printed, frame)
    }
}
