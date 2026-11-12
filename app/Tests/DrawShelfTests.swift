import XCTest

/// Proves the list of boards that the Draw window and spot show.
final class DrawShelfTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shelf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
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

        try Shelf(folder: folder).rename(file, to: "  Launch flow ")

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

    func testANewBoardIsAnEmptyUntitledBoardOnTheShelf() throws {
        let shelf = Shelf(folder: folder)

        let file = try shelf.make()

        XCTAssertEqual(try Board.load(from: file), Board())
        XCTAssertEqual(shelf.entries.map(\.file.lastPathComponent), [file.lastPathComponent])
    }
}
