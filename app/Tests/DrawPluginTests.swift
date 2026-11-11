import XCTest
@testable import OpenspotCore

/// Proves the Draw spot with its real script in a private home: its boards, a rename, a delete, and its app's source.
final class DrawPluginTests: SamplePluginsCase {
    private func draw() throws -> Spot {
        try XCTUnwrap(try scan.commands.first { $0.id == "draw" })
    }

    /// Runs the body with the data folder of Draw under a private config.
    private func withBoards(_ body: (URL, URL) async throws -> Void) async throws {
        try await withPrivateHome { folder in
            let config = folder.appendingPathComponent("config")
            setenv("OPENSPOT_CONFIG", config.path, 1)
            defer { unsetenv("OPENSPOT_CONFIG") }
            let boards = config.appendingPathComponent("data/draw/boards")
            try FileManager.default.createDirectory(at: boards, withIntermediateDirectories: true)
            try await body(folder, boards)
        }
    }

    private func write(_ title: String, id: String, in boards: URL, age: TimeInterval) throws {
        let file = boards.appendingPathComponent("\(id).json")
        try Board(title: title).save(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: file.path)
    }

    func testTheSheetListsANewBoardThenTheBoardsNewestFirst() async throws {
        let spot = try draw()
        try await withBoards { _, boards in
            try write("Old plan", id: "old", in: boards, age: 7200)
            try write("Flows", id: "flows", in: boards, age: 120)

            let rows = try await spot.items(timeout: 5).items

            XCTAssertEqual(rows.map(\.title), ["New board", "Flows", "Old plan"])
            XCTAssertEqual(rows.map(\.run), ["new", "flows", "old"])
            XCTAssertEqual(rows[1].subtitle, "Edited 2 min ago")
            XCTAssertEqual(rows[2].subtitle, "Edited 2 h ago")
        }
    }

    func testARenameKeepsTheFiguresAndChangesTheTitle() async throws {
        let spot = try draw()
        try await withBoards { _, boards in
            var board = Board(title: "Untitled board")
            board.add(Figure(kind: .shape, points: [.zero, CGPoint(x: 10, y: 10)]))
            try board.save(to: boards.appendingPathComponent("a.json"))
            let rows = try await spot.items(timeout: 5).items
            let item = try XCTUnwrap(rows.first { $0.run == "a" })
            let rename = try await action("rename", of: spot)
            var draft = FormDraft(form: try await spot.form(rename, item: item, timeout: 5))
            XCTAssertEqual(draft.form.fields.map(\.value), ["Untitled board"])
            draft.set("Launch flow", for: "name")

            _ = try await spot.submit(rename, item: item, draft: draft, timeout: 5)

            let renamed = try Board.load(from: boards.appendingPathComponent("a.json"))
            XCTAssertEqual(renamed.title, "Launch flow")
            XCTAssertEqual(renamed.figures, board.figures)
        }
    }

    func testADeleteMovesTheBoardToTheTrash() async throws {
        let spot = try draw()
        try await withBoards { folder, boards in
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(".Trash"), withIntermediateDirectories: true)
            try write("Flows", id: "flows", in: boards, age: 0)
            let rows = try await spot.items(timeout: 5).items
            let item = try XCTUnwrap(rows.first { $0.run == "flows" })

            let toast = try await spot.perform(.action(try await action("delete", of: spot), item: item), timeout: 5)

            XCTAssertEqual(toast, "Moved Flows to the Trash.")
            XCTAssertFalse(FileManager.default.fileExists(atPath: boards.appendingPathComponent("flows.json").path))
            let trash = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent(".Trash").path)
            XCTAssertEqual(trash.count, 1)
            XCTAssertTrue(trash[0].hasPrefix("Flows-"))
        }
    }

    func testOpeningAGoneBoardSaysSo() async throws {
        let spot = try draw()
        try await withBoards { _, _ in
            do {
                try await spot.perform(.item(SpotItem(title: "Gone", run: "gone")), timeout: 5)
                XCTFail("expected a failure")
            } catch let error as PluginError {
                XCTAssertEqual(error.reason, "This board is gone.")
            }
        }
    }

    func testTheBoardAppTypeChecks() async throws {
        let folder = try draw().url.deletingPathExtension()
        let sources = try ["model", "app"].flatMap { part in
            try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent(part).path)
                .filter { $0.hasSuffix(".swift") }
                .map { folder.appendingPathComponent("\(part)/\($0)").path }
        }

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck"] + sources)
    }
}
