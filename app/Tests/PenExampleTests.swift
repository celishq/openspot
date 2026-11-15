import XCTest
@testable import OpenspotCore

final class PenExampleTests: SampleSpotsCase {
    private func dataFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-pen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func press(_ data: URL) throws {
        let press = Process()
        press.executableURL = URL(fileURLWithPath: "/bin/sh")
        press.arguments = [examples.appendingPathComponent("pen.spot/pen.sh").path, "draw"]
        press.environment = ["PATH": "/usr/bin:/bin", "OPENSPOT_DATA": data.path]
        try press.run()
        press.waitUntilExit()
        XCTAssertEqual(press.terminationStatus, 0)
    }

    private func pid(in data: URL) -> pid_t? {
        pid_t((try? String(contentsOf: data.appendingPathComponent("pen.pid"), encoding: .utf8)) ?? "")
    }

    func testThePenLoadsAsAnExample() throws {
        let pen = try example("Pen")

        XCTAssertEqual(pen.id, "pen")
    }

    func testAPressStartsTheOverlayAndKeepsItsProcess() async throws {
        let data = try dataFolder()
        defer { try? FileManager.default.removeItem(at: data) }
        let started = data.appendingPathComponent("started")
        try "#!/bin/sh\ntouch '\(started.path)'\n\(String.longLoop)\n".writeScript(to: data.appendingPathComponent("pen-overlay"))

        try press(data)
        try await wait("the start") { FileManager.default.fileExists(atPath: started.path) }
        defer { if let overlay = pid(in: data) { kill(overlay, SIGKILL) } }

        XCTAssertTrue(FileManager.default.fileExists(atPath: started.path))
        XCTAssertEqual(pid(in: data).map { kill($0, 0) }, 0)
    }

    func testASecondPressClosesTheOverlayAndStartsNoOther() async throws {
        let data = try dataFolder()
        defer { try? FileManager.default.removeItem(at: data) }
        let overlay = data.appendingPathComponent("pen-overlay")
        let source = data.appendingPathComponent("wait.swift")
        try "import Foundation\nsleep(600)\n".write(to: source, atomically: true, encoding: .utf8)
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-o", overlay.path, source.path])
        let running = try TestChild(overlay.path, [])
        defer { running.stop() }
        try String(running.processIdentifier).write(to: data.appendingPathComponent("pen.pid"), atomically: true, encoding: .utf8)

        try press(data)
        try await wait("the end of the pen") { kill(running.processIdentifier, 0) != 0 }

        XCTAssertNotEqual(kill(running.processIdentifier, 0), 0)
        XCTAssertNil(pid(in: data))
    }

    func testTheOverlayBuilds() async throws {
        let (folder, pen) = try await built("pen")
        defer { try? FileManager.default.removeItem(at: folder) }

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: pen.path))
    }
}
