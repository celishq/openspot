import XCTest

final class DrawShelfTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = try emptyFolder()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testTheShelfListsTheBoardsNewestFirstWithTheirTitles() throws {
        for (name, age) in [("old", 7200.0), ("new", 60.0)] {
            let file = folder.appendingPathComponent("\(name).json")
            try Board(title: name.capitalized).save(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: file.path)
        }
        try Data().write(to: folder.appendingPathComponent("new.png"))

        let entries = Shelf(folder: folder).entries

        XCTAssertEqual(entries.map(\.title), ["New", "Old"])
        XCTAssertEqual(entries[0].picture.lastPathComponent, "new.png")
    }

    func testARenameOnTheShelfKeepsTheFiguresOfTheBoard() throws {
        var board = Board(title: "Old")
        board.add(Figure(kind: .shape, points: [.zero, CGPoint(x: 10, y: 10)]))
        let file = folder.appendingPathComponent("a.json")
        try board.save(to: file)

        _ = try Shelf(folder: folder).rename(file, to: "  Launch flow ")

        let renamed = try Board.load(from: file)
        XCTAssertEqual(renamed.title, "Launch flow")
        XCTAssertEqual(renamed.figures, board.figures)
    }

    func testTrashTakesTheBoardWithItsPictureAndImages() throws {
        let file = folder.appendingPathComponent("a.json")
        try Board(title: "A").save(to: file)
        try Data().write(to: folder.appendingPathComponent("a.png"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("a.assets"), withIntermediateDirectories: true)
        try Board(title: "B").save(to: folder.appendingPathComponent("b.json"))
        var trashed: [String] = []

        try Shelf(folder: folder).discard(file) { trashed.append($0.lastPathComponent) }

        XCTAssertEqual(trashed.sorted(), ["a.assets", "a.json", "a.png"])
    }

    func testASearchFindsBoardsByAnyPartOfTheTitleIgnoringCaseAndAccents() throws {
        for (id, title) in [("a", "Café flows"), ("b", "Launch plan"), ("c", "Old cafe")] {
            try Board(title: title).save(to: folder.appendingPathComponent("\(id).json"))
        }
        let shelf = Shelf(folder: folder)

        XCTAssertEqual(Set(shelf.entries(matching: "CAFE").map(\.title)), ["Café flows", "Old cafe"])
        XCTAssertEqual(shelf.entries(matching: "plan").map(\.title), ["Launch plan"])
        XCTAssertEqual(shelf.entries(matching: "  ").count, 3)
    }

    func testASearchTypedInTheOtherKeyboardLayoutStillFinds() throws {
        for (id, title) in [("a", "test"), ("b", "тест"), ("c", "Plan")] {
            try Board(title: title).save(to: folder.appendingPathComponent("\(id).json"))
        }
        let shelf = Shelf(folder: folder)

        XCTAssertEqual(shelf.entries(matching: "еуіе").map(\.title), ["test"])
        XCTAssertEqual(shelf.entries(matching: "ntcn").map(\.title), ["тест"])
        XCTAssertEqual(shelf.entries(matching: "здф").map(\.title), ["Plan"])
    }

    func testANewBoardIsAnEmptyUntitledBoardOnTheShelf() throws {
        let shelf = Shelf(folder: folder)

        let file = try shelf.make(in: nil)

        XCTAssertEqual(try Board.load(from: file), Board())
        XCTAssertEqual(shelf.entries.map(\.file.lastPathComponent), [file.lastPathComponent])
    }

    func testTheTreeHoldsFoldersFirstThenBoardsAndSkipsImageFolders() throws {
        try Board(title: "Top").save(to: folder.appendingPathComponent("top.json"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("top.assets"), withIntermediateDirectories: true)
        let work = folder.appendingPathComponent("Work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try Board(title: "Inside").save(to: work.appendingPathComponent("inside.json"))

        let tree = Shelf(folder: folder).tree

        XCTAssertEqual(tree.map(\.title), ["Work", "Top"])
        XCTAssertEqual(tree.map(\.isFolder), [true, false])
        XCTAssertEqual(tree[0].children.map(\.title), ["Inside"])
        XCTAssertEqual(Set(Shelf(folder: folder).entries.map(\.title)), ["Top", "Inside"])
    }

    func testNewThingsGoWhereThePickIs() throws {
        let shelf = Shelf(folder: folder)
        let work = try shelf.makeFolder(in: nil)
        let again = try shelf.makeFolder(in: nil)
        XCTAssertEqual([work, again].map(\.lastPathComponent), ["New Folder", "New Folder 2"])

        let board = try shelf.make(in: shelf.place(for: work))
        XCTAssertEqual(board.deletingLastPathComponent().standardizedFileURL, work.standardizedFileURL)
        XCTAssertEqual(shelf.place(for: board).standardizedFileURL, work.standardizedFileURL)
        XCTAssertEqual(shelf.place(for: nil).standardizedFileURL, folder.standardizedFileURL)
    }

    func testAFolderRenamesAndGoesToTheTrashWhole() throws {
        let shelf = Shelf(folder: folder)
        let work = try shelf.makeFolder(in: nil)
        try shelf.make(in: work)

        let renamed = try shelf.rename(work, to: "Plans/2026")
        XCTAssertEqual(renamed.lastPathComponent, "Plans-2026")
        XCTAssertEqual(shelf.tree.first?.children.count, 1)

        var trashed: [String] = []
        try shelf.discard(renamed) { trashed.append($0.lastPathComponent) }
        XCTAssertEqual(trashed, ["Plans-2026"])
    }

    func testAMoveTakesABoardWithItsPictureAndImagesIntoAFolder() throws {
        let shelf = Shelf(folder: folder)
        let work = try shelf.makeFolder(in: nil)
        let file = try shelf.make(in: nil)
        let base = file.deletingPathExtension()
        try Data().write(to: base.appendingPathExtension("png"))
        try FileManager.default.createDirectory(at: base.appendingPathExtension("assets"), withIntermediateDirectories: true)

        let moved = try shelf.move(file, into: work)

        XCTAssertEqual(moved.deletingLastPathComponent().standardizedFileURL, work.standardizedFileURL)
        for ending in ["png", "assets"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: moved.deletingPathExtension().appendingPathExtension(ending).path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathExtension(ending).path))
        }
    }

    func testAFolderMovesIntoAnotherWithAFreeNameAndNeverIntoItself() throws {
        let shelf = Shelf(folder: folder)
        let outer = try shelf.makeFolder(in: nil)
        let inner = try shelf.makeFolder(in: outer)
        let twin = try shelf.makeFolder(in: nil)

        XCTAssertThrowsError(try shelf.move(outer, into: inner))
        let moved = try shelf.move(twin, into: outer)

        XCTAssertEqual(moved.lastPathComponent, "New Folder 2")
        XCTAssertEqual(Set(shelf.tree.first?.children.map(\.title) ?? []), ["New Folder", "New Folder 2"])
        let again = try shelf.makeFolder(in: nil)
        try shelf.move(again, into: inner)
        XCTAssertEqual(try shelf.move(shelf.makeFolder(in: nil), into: inner).lastPathComponent, "New Folder 3")
    }

    func testTheShelfListsABoardWhoseFiguresItCannotReadByItsTitle() throws {
        try Data(#"{"title":"Plan","figures":"none"}"#.utf8).write(to: folder.appendingPathComponent("plan.json"))

        XCTAssertEqual(Shelf(folder: folder).entries.map(\.title), ["Plan"])
    }

    func testTheShelfReadsABoardAgainOnlyWhenItsFileChanges() throws {
        let file = folder.appendingPathComponent("plan.json")
        try Data(#"{"title":"Plan A","figures":[]}"#.utf8).write(to: file)
        let changed = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: changed], ofItemAtPath: file.path)
        XCTAssertEqual(Shelf(folder: folder).entries.map(\.title), ["Plan A"])

        let handle = try FileHandle(forWritingTo: file)
        try handle.write(contentsOf: Data(#"{"title":"Plan B","figures":[]}"#.utf8))
        try handle.close()
        try FileManager.default.setAttributes([.modificationDate: changed], ofItemAtPath: file.path)
        XCTAssertEqual(Shelf(folder: folder).entries.map(\.title), ["Plan A"])

        try Data(#"{"title":"Plan C","figures":[]}"#.utf8).write(to: file, options: .atomic)
        XCTAssertEqual(Shelf(folder: folder).entries.map(\.title), ["Plan C"])
    }

    func testARenameOfABoardThatFailsToLoadLeavesItsFileAsItWas() throws {
        let file = folder.appendingPathComponent("plan.json")
        let bytes = Data(#"{"title":"Plan","figures":"none"}"#.utf8)
        try bytes.write(to: file)

        XCTAssertThrowsError(try Shelf(folder: folder).rename(file, to: "Other"))

        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
}
