import AppKit
import XCTest

@MainActor
final class DrawStudioTests: XCTestCase {
    private var folder: URL!
    private let bad = Data(#"{"title":"Plan","figures":"none"}"#.utf8)

    override func setUp() async throws {
        folder = try emptyFolder()
    }

    override func tearDown() async throws {
        Saves.shared.wait()
        try? FileManager.default.removeItem(at: folder)
    }

    private func box(_ x: CGFloat = 0) -> Figure {
        Figure(kind: .shape, points: [CGPoint(x: x, y: 0), CGPoint(x: x + 100, y: 60)])
    }

    private func board(_ name: String, title: String = "Flows", figures: [Figure] = []) throws -> URL {
        let file = folder.appendingPathComponent("\(name).json")
        try Board(title: title, figures: figures).save(to: file)
        return file
    }

    private func number(of file: URL) throws -> Int {
        try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? Int)
    }

    func testAStudioOpensABoardWithItsTitleAndItsFigures() throws {
        let file = try board("flows", figures: [box()])

        let studio = try Studio(file: file)

        XCTAssertEqual(studio.board, try Board.load(from: file))
        XCTAssertEqual(studio.board.title, "Flows")
        XCTAssertFalse(studio.canUndo)
    }

    func testABoardThatFailsToLoadGetsNoStudioAndItsFileStaysAsItWas() throws {
        let file = folder.appendingPathComponent("plan.json")
        try bad.write(to: file)

        XCTAssertThrowsError(try Studio(file: file))

        XCTAssertEqual(try Data(contentsOf: file), bad)
    }

    func testABoardThatFailsToLoadGetsNoTabAndTheDeskNeverWritesIt() throws {
        let file = folder.appendingPathComponent("plan.json")
        try bad.write(to: file)
        let desk = Desk(folder: folder, shows: false)

        XCTAssertThrowsError(try desk.open(file))
        desk.finish()

        XCTAssertTrue(desk.tabs.studios.isEmpty)
        XCTAssertTrue(desk.tabs.home)
        XCTAssertEqual(try Data(contentsOf: file), bad)
    }

    func testAChangeIsSavedWithThePictureOfTheBoard() throws {
        let file = try board("flows")
        let studio = try Studio(file: file)
        let added = box()

        studio.change { $0.add(added) }
        studio.save()
        Saves.shared.wait()

        XCTAssertEqual(try Board.load(from: file).figures, [added])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("flows.png").path))
    }

    func testASaveOfABoardThatDidNotChangeWritesNothing() throws {
        let file = try board("flows", figures: [box()])
        let studio = try Studio(file: file)
        let before = try number(of: file)

        studio.save()
        studio.change { $0.add(self.box(200)) }
        studio.undo()
        studio.save()
        Saves.shared.wait()

        XCTAssertEqual(try number(of: file), before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("flows.png").path))
    }

    func testASaveTakesThePlaceOfTheOldFileWhole() throws {
        let file = try board("flows")
        let studio = try Studio(file: file)
        let before = try number(of: file)

        studio.change { $0.add(self.box()) }
        studio.save()
        Saves.shared.wait()

        XCTAssertNotEqual(try number(of: file), before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(), ["flows.json", "flows.png"])
    }

    func testASaveWritesTheFileOffTheMainThread() throws {
        let saves = Saves()
        let file = try board("flows")
        let studio = try Studio(file: file, saves: saves)
        saves.pause()

        studio.change { $0.add(self.box()) }
        studio.save()
        let held = try Board.load(from: file).figures.count
        saves.resume()
        saves.wait()

        XCTAssertEqual(held, 0)
        XCTAssertEqual(try Board.load(from: file).figures.count, 1)
    }

    func testAWriteThatFailsIsTriedAgainAtTheNextSave() async throws {
        let file = try board("flows")
        let studio = try Studio(file: file)
        studio.change { $0.add(self.box()) }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        studio.save()
        Saves.shared.wait()
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        XCTAssertEqual(try Board.load(from: file).figures.count, 0)
        await Task.yield()
        let told = expectation(description: "the studio hears of the failed write")
        DispatchQueue.main.async { told.fulfill() }
        await fulfillment(of: [told], timeout: 60)

        studio.save()
        Saves.shared.wait()

        XCTAssertEqual(try Board.load(from: file).figures.count, 1)
    }

    func testABoardWhoseFileIsGoneIsNotWrittenBackAndItsTabCloses() throws {
        let file = try board("flows")
        let studio = try Studio(file: file)
        var closed = 0
        studio.gone = { closed += 1 }
        try FileManager.default.removeItem(at: file)

        studio.change { $0.add(self.box()) }
        studio.save()
        Saves.shared.wait()

        XCTAssertEqual(closed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testUndoAndRedoGoThroughTheChangesOneByOne() throws {
        let studio = try Studio(file: try board("flows"))
        let first = box()
        let second = box(200)

        studio.change { $0.add(first) }
        studio.change { $0.add(second) }
        studio.change { $0.update(first.id) { $0.text = "one" } }

        studio.undo()
        XCTAssertEqual(studio.board.figures, [first, second])
        studio.undo()
        XCTAssertEqual(studio.board.figures, [first])
        studio.redo()
        studio.redo()
        XCTAssertEqual(studio.board[first.id]?.text, "one")
        XCTAssertFalse(studio.canRedo)
        XCTAssertTrue(studio.canUndo)
    }

    func testTheStepsToUndoKeepTheChangedFiguresNotTheBoard() throws {
        let figures = (0..<200).map { box(CGFloat($0) * 200) }
        let studio = try Studio(file: try board("flows", figures: figures))

        for index in 0..<50 { studio.change { $0.update(figures[index].id) { $0.text = "changed" } } }

        XCTAssertEqual(studio.kept, 100)
    }

    func testARenameIsSavedAtOnceAndUndoKeepsIt() throws {
        let file = try board("flows", title: "Old", figures: [box()])
        let studio = try Studio(file: file)
        studio.change { $0.add(self.box(200)) }

        studio.rename("  New name ")
        Saves.shared.wait()
        studio.undo()
        studio.save()
        Saves.shared.wait()

        let kept = try Board.load(from: file)
        XCTAssertEqual(kept.title, "New name")
        XCTAssertEqual(kept.figures.count, 1)
        XCTAssertEqual(Shelf(folder: folder).entries.map(\.title), ["New name"])
    }

    func testABoardThatClosedOpensAgainAsItWasLeft() throws {
        let file = try board("flows")
        let desk = Desk(folder: folder, shows: false)
        try desk.open(file)
        let studio = try XCTUnwrap(desk.studio)
        studio.change { $0.add(self.box()) }
        studio.change { $0.add(self.box(200)) }
        let left = studio.board

        desk.finish()

        let again = Desk(folder: folder, shows: false)
        try again.open(file)
        XCTAssertEqual(again.studio?.board, left)
    }

    func testTwoBoardsOpenInTwoTabsAndASecondOpenOfABoardShowsItsTab() throws {
        let flows = try board("flows")
        let plan = try board("plan", title: "Plan")
        let desk = Desk(folder: folder, shows: false)

        try desk.open(flows)
        try desk.open(plan)
        desk.studio?.change { $0.add(self.box()) }
        try desk.open(flows)

        XCTAssertEqual(desk.tabs.studios.map(\.board.title), ["Flows", "Plan"])
        XCTAssertEqual(desk.studio?.file, flows)
        Saves.shared.wait()
        XCTAssertEqual(try Board.load(from: plan).figures.count, 1)
        desk.finish()
        XCTAssertEqual(try Board.load(from: flows).figures.count, 0)
    }

    func testABoardThatMovesIntoAFolderKeepsItsTabItsChangesAndItsSteps() throws {
        let file = try board("flows")
        let work = folder.appendingPathComponent("Work", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let desk = Desk(folder: folder, shows: false)
        try desk.open(file)
        desk.studio?.change { $0.add(self.box()) }

        desk.move([file], into: work)
        desk.finish()

        let moved = work.appendingPathComponent("flows.json")
        XCTAssertEqual(desk.studio?.file.path, moved.path)
        XCTAssertEqual(desk.studio?.canUndo, true)
        XCTAssertEqual(try Board.load(from: moved).figures.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testTheTabOfABoardWhoseFileWentClosesWhenTheWindowComesForwardAndWritesNothing() throws {
        let file = try board("flows")
        let desk = Desk(folder: folder, shows: false)
        try desk.open(file)
        desk.studio?.change { $0.add(self.box()) }
        Saves.shared.wait()
        try FileManager.default.removeItem(at: file)

        desk.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        desk.finish()

        XCTAssertTrue(desk.tabs.studios.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testClosingTheTabsOfABoardLeavesNoWriteThatCouldBringItsFileBack() throws {
        let file = try board("flows")
        let desk = Desk(folder: folder, shows: false)
        try desk.open(file)
        desk.studio?.change { $0.add(self.box()) }

        desk.close(boardsAt: [file])
        try FileManager.default.removeItem(at: file)
        Saves.shared.wait()

        XCTAssertTrue(desk.tabs.studios.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}
