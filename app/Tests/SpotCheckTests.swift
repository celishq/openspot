import XCTest
@testable import OpenspotCore

/// Proves that a check names the spot and the file of each fault, in words and in JSON for an agent.
@MainActor
final class SpotCheckTests: XCTestCase {
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
        try "#!/bin/sh\n# size=huge\necho\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(findings, [SpotCheck.Finding(spot: "weather", file: file.path, fault: "Weather has an unknown size: huge")])
        let json = try JSONSerialization.jsonObject(with: Data(SpotCheck.json(findings).utf8)) as? [[String: String]]
        XCTAssertEqual(json, [["spot": "weather", "file": file.path, "fault": "Weather has an unknown size: huge"]])
    }

    func testStayIsAFaultThatNamesTheMode() async throws {
        let file = folder.appendingPathComponent("relay.sh")
        try "#!/bin/sh\n# stay=true\necho\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["Relay has stay, which Openspot no longer reads. Use mode=stay or mode=always"])
    }

    func testAValueWithANewLinePrintedByHandIsAFaultThatNamesTheHelper() async throws {
        let file = folder.appendingPathComponent("notes.sh")
        try "#!/bin/sh\n# read=sheet\nprintf 'row=a\\ntitle=one\\ntwo\\n\\nrow=b\\ntitle=B\\ntitle=C\\n'\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the block row=a has a line with no =, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc",
            "the block row=b has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        ])
    }

    func testNoFaultIsAnEmptyList() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: folder.appendingPathComponent("hello.sh"))

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(SpotCheck.json(findings), "[]\n")
    }
}
