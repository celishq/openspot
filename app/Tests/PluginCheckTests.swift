import XCTest
@testable import OpenspotCore

/// Proves that a check names the spot and the file of each fault, in words and in JSON for an agent.
@MainActor
final class PluginCheckTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testAFindingNamesItsSpotItsFileAndItsFault() async throws {
        let file = folder.appendingPathComponent("weather.sh")
        try "#!/bin/sh\n# shortcut=??\necho\n".writeScript(to: file)

        let findings = await PluginCheck(folder: PluginFolder(url: folder)).findings()

        XCTAssertEqual(findings, [PluginCheck.Finding(spot: "weather", file: file.path, fault: "Weather has an unknown shortcut: ??")])
        let json = try JSONSerialization.jsonObject(with: Data(PluginCheck.json(findings).utf8)) as? [[String: String]]
        XCTAssertEqual(json, [["spot": "weather", "file": file.path, "fault": "Weather has an unknown shortcut: ??"]])
    }

    func testNoFaultIsAnEmptyList() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: folder.appendingPathComponent("hello.sh"))

        let findings = await PluginCheck(folder: PluginFolder(url: folder)).findings()

        XCTAssertEqual(PluginCheck.json(findings), "[]\n")
    }
}
