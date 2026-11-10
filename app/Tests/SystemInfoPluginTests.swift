import XCTest
@testable import OpenspotCore

/// Proves the System details spot with its real script beside fake metric scripts, in a private home.
final class SystemInfoPluginTests: SamplePluginsCase {
    private func systemInfo() throws -> Spot {
        try XCTUnwrap(try scan.commands.first { $0.name == "System details" })
    }

    /// Copies the real script into a folder beside fake metric scripts. The fake CPU counts its looks, so that each read
    /// differs from the one before.
    private func copy(in folder: URL) throws -> URL {
        let place = folder.appendingPathComponent("spots")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        let script = place.appendingPathComponent("system-info.sh")
        try String(contentsOf: try systemInfo().url, encoding: .utf8).writeScript(to: script)
        let counter = folder.appendingPathComponent("looks").path
        for (name, body) in [
            ("battery.sh", "printf 'title=50%%\\nvalue=0.5\\n'"),
            ("devices.sh", ":"),
            ("cpu.sh", "n=$(cat '\(counter)' 2>/dev/null); echo $((n + 1)) > '\(counter)'; printf 'title=%s%%\\nvalue=0.1\\n' \"$n\""),
            ("memory.sh", "printf 'title=40%%\\nvalue=0.4\\n'")
        ] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: place.appendingPathComponent(name))
        }
        try "#!/bin/sh\nprintf '1.0 Finder\\n'\n".writeScript(to: folder.appendingPathComponent("tools/ps"))
        return script
    }

    private static func frames(of script: URL) async throws -> [String] {
        var frames: [String] = []
        for try await frame in ScriptProcess(url: script, arguments: ["read"], limit: 10).start() { frames.append(frame) }
        return frames
    }

    func testSystemDetailsReadsOnlyWhenItsSheetOpens() throws {
        let read = try XCTUnwrap(try systemInfo().read)

        XCTAssertTrue(read.has(.sheet))
        XCTAssertFalse(read.has(.panel))
    }

    func testASecondReadShowsTheLastAnswerFirstThenTheFreshOne() async throws {
        try await withPrivateHome { folder in
            let script = try self.copy(in: folder)

            let first = try await Self.frames(of: script)
            let second = try await Self.frames(of: script)

            XCTAssertEqual(first.count, 1)
            XCTAssertTrue(first.first?.contains("title=CPU") == true)
            XCTAssertEqual(second.count, 2)
            XCTAssertEqual(second.first, first.first)
            XCTAssertNotEqual(second.last, first.first)
        }
    }
}
