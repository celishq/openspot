import XCTest
@testable import OpenspotCore

/// Proves the Shelf example with its real script: it keeps dropped files, gives each one back as a row with its file, and
/// forgets a file that a drag took out (07).
final class ShelfExampleTests: SamplePluginsCase {
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

            _ = try await shelf.perform(.drop(paths: files), timeout: 5)
            _ = try await shelf.perform(.drop(paths: [files[0]]), timeout: 5)
            let kept = try await shelf.items(timeout: 5).items

            XCTAssertEqual(kept.map(\.title), ["a.txt", "b\\c.txt"])
            XCTAssertEqual(kept.map(\.file), files)
            XCTAssertEqual(kept.map(\.subtitle), ["~", "~"])

            _ = try await shelf.perform(.drag(runs: [files[0]]), timeout: 5)

            let left = try await shelf.items(timeout: 5).items
            XCTAssertEqual(left.map(\.run), [files[1]])

            try FileManager.default.removeItem(atPath: files[1])

            let gone = try await shelf.items(timeout: 5).items
            XCTAssertEqual(gone, [])
        }
    }

    func testClearForgetsEachFile() async throws {
        let shelf = try shelf
        try await withPrivateHome { folder in
            let file = folder.appendingPathComponent("a.txt").path
            try Data().write(to: URL(fileURLWithPath: file))
            _ = try await shelf.perform(.drop(paths: [file]), timeout: 5)

            _ = try await shelf.perform(SpotAction(arguments: ["clear"]), timeout: 5)

            let items = try await shelf.items(timeout: 5).items
            XCTAssertEqual(items, [])
        }
    }
}
