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
        try "#!/bin/sh\n# on=sheet.open\nprintf 'row=a\\ntitle=one\\ntwo\\n\\nrow=b\\ntitle=B\\ntitle=C\\n'\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the block row=a has a line with no =, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc",
            "the block row=b has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        ])
    }

    func testAnEventThatNoSpotRaisesIsAFaultThatNamesTheFix() async throws {
        try "#!/bin/sh\n# on=music.track\n# on=clipboard.change\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.appendingPathComponent("song.sh"))

        let alone = await SpotCheck(folder: SpotFolder(url: folder)).findings()
        try "#!/bin/sh\n# emits=music.track\n".writeScript(to: folder.appendingPathComponent("player.sh"))
        let named = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(alone.map(\.fault), ["Song reads on music.track, which Openspot does not raise and no spot names in its emits. Add emits=music.track to the spot that raises it, or fix the name"])
        XCTAssertEqual(named, [])
    }

    func testASpotThatReadsOnTheEventItRaisesIsWarned() async throws {
        try "#!/bin/sh\n# title=Song\n# on=music.track\n# emits=music.track\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.appendingPathComponent("song.sh"))

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["Song reads on music.track and raises it, so a raise from its read would read it again without end. Raise it from an action, or rename one of them"])
    }

    func testNoFaultIsAnEmptyList() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: folder.appendingPathComponent("hello.sh"))

        let findings = await SpotCheck(folder: SpotFolder(url: folder)).findings()

        XCTAssertEqual(SpotCheck.json(findings), "[]\n")
    }

    func testAStoppedCheckRunsNoMoreReads() async throws {
        let started = folder.appendingPathComponent("started")
        let far = folder.appendingPathComponent("far")
        let body = "if [ -f '\(started.path)' ]; then touch '\(far.path)'; fi; touch '\(started.path)'; sleep 30"
        try "#!/bin/sh\n# on=sheet.open\n\(body)\n".writeScript(to: folder.appendingPathComponent("first.sh"))
        try "#!/bin/sh\n# on=sheet.open\n\(body)\n".writeScript(to: folder.appendingPathComponent("second.sh"))
        let check = Task { await SpotCheck(folder: SpotFolder(url: folder), timeout: 60).findings() }
        for _ in 0..<1000 {
            if FileManager.default.fileExists(atPath: started.path) { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        check.cancel()
        _ = await check.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: far.path))
    }
}
