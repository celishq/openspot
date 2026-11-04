import XCTest
@testable import OpenspotCore

final class PluginFolderTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws {
        let url = folder.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func testKeepsApiOneAndRefusesUnknownApi() throws {
        try writePlugin("good.sh", "#!/bin/sh\n# @name Good\n# @api 1\n")
        try writePlugin("plain.sh", "#!/bin/sh\necho no header\n")
        try writePlugin("future.sh", "#!/bin/sh\n# @name Future\n# @api 9\n")

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.plugins.map(\.name), ["Good"])
        XCTAssertEqual(scan.refused.map(\.file), ["future.sh"])
    }
}
