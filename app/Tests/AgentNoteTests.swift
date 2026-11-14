import XCTest
@testable import OpenspotCore

final class AgentNoteTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-note-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheNoteNamesTheCommandsOfABuildAndClaudeReadsIt() throws {
        try AgentNote(command: "/Apps/Openspot.app/Contents/Helpers/openspot").write(in: folder)

        let note = try XCTUnwrap(saved("AGENTS.md"))
        for word in ["openspot guide", "openspot spot new", "openspot spot run", "openspot spot log", "openspot check --json", "openspot spot show", "/Apps/Openspot.app/Contents/Helpers/openspot"] {
            XCTAssertTrue(note.contains(word), word)
        }
        XCTAssertEqual(saved("CLAUDE.md"), "@AGENTS.md\n")
    }

    func testANoteOfTheAppFollowsTheCommandAndANoteOfThePersonStays() throws {
        try AgentNote(command: "/old/openspot").write(in: folder)
        try AgentNote(command: "/new/openspot").write(in: folder)
        XCTAssertTrue(saved("AGENTS.md")?.contains("/new/openspot") == true)

        try "My own rules\n".write(to: folder.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try AgentNote(command: "/new/openspot").write(in: folder)
        XCTAssertEqual(saved("AGENTS.md"), "My own rules\n")
    }

    func testTheNoteGivesNoSpot() throws {
        try AgentNote(command: "/Apps/openspot").write(in: folder)

        XCTAssertEqual(try SpotsFolder(url: folder).scan().spots, [])
    }
}
