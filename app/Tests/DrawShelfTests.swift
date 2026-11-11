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

    func testANewBoardIsAnEmptyUntitledBoardOnTheShelf() throws {
        let shelf = Shelf(folder: folder)

        let file = try shelf.make()

        XCTAssertEqual(try Board.load(from: file), Board())
        XCTAssertEqual(shelf.entries.map(\.file.lastPathComponent), [file.lastPathComponent])
    }
}
