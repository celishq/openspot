import XCTest
@testable import OpenspotCore

final class ShelfExampleTests: SampleSpotsCase {
    private var shelf: Spot {
        get throws {
            try example("Shelf")
        }
    }

    func testItKeepsDroppedFilesOnceAndForgetsWhatADragTookOut() async throws {
        let shelf = try shelf
        try await withPrivateHome { folder in
            let files = ["a.txt", "b\\c.txt"].map { folder.appendingPathComponent($0).path }
            try files.forEach { try Data().write(to: URL(fileURLWithPath: $0)) }

            try await shelf.handle(ScriptEntry.drop.name, files, timeout: 60)
            try await shelf.handle(ScriptEntry.drop.name, [files[0]], timeout: 60)
            let kept = try await shelf.items(timeout: 60).items

            XCTAssertEqual(kept.map(\.title), ["a.txt", "b\\c.txt"])
            XCTAssertEqual(kept.map(\.file), files)
            XCTAssertEqual(kept.map(\.subtitle), ["~", "~"])
            XCTAssertEqual(try self.read("selected", in: folder), "\(files[0])\n\(files[0])\n")

            try await shelf.handle(ScriptEntry.drag.name, [files[0]], timeout: 60)

            let left = try await shelf.items(timeout: 60).items
            XCTAssertEqual(left.map(\.run), [files[1]])

            try FileManager.default.removeItem(atPath: files[1])

            let gone = try await shelf.items(timeout: 60).items
            XCTAssertEqual(gone, [])
        }
    }

    func testClearForgetsEachFile() async throws {
        let shelf = try shelf
        try await withPrivateHome { folder in
            let file = folder.appendingPathComponent("a.txt").path
            try Data().write(to: URL(fileURLWithPath: file))
            try await shelf.handle(ScriptEntry.drop.name, [file], timeout: 60)

            _ = try await shelf.perform("clear", timeout: 60)

            let items = try await shelf.items(timeout: 60).items
            XCTAssertEqual(items, [])
        }
    }
}
