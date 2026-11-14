import XCTest
@testable import OpenspotCore

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
        let file = folder.spotFile("weather")
        try "#!/bin/sh\n# mode=huge\necho\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings, [SpotCheck.Finding(spot: "weather", file: file.path, fault: "Weather has an unknown mode: huge. Use once, stay or always")])
        let json = try JSONSerialization.jsonObject(with: Data(SpotCheck.json(findings).utf8)) as? [[String: String]]
        XCTAssertEqual(json, [["spot": "weather", "file": file.path, "fault": "Weather has an unknown mode: huge. Use once, stay or always"]])
    }

    func testStayIsAFaultThatNamesTheMode() async throws {
        let file = folder.spotFile("relay")
        try "#!/bin/sh\n# stay=true\necho\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["Relay has stay, which Openspot no longer reads. Use mode=stay or mode=always"])
    }

    func testAValueWithANewLinePrintedByHandIsAFaultThatNamesTheHelper() async throws {
        let file = folder.spotFile("notes")
        try "#!/bin/sh\n# on=sheet.open\nprintf 'row=a\\ntitle=one\\ntwo\\n\\nrow=b\\ntitle=B\\ntitle=C\\n'\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the block row=a has a line with no =, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc",
            "the block row=b has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        ])
    }

    func testACardThatNamesASpotWithNoEventIsAFaultThatNamesTheFix() async throws {
        try "#!/bin/sh\n# title=Plain\necho\n".writeScript(to: folder.spotFile("plain"))
        try "#!/bin/sh\n# title=W\n# grid.square=plain\n".writeScript(to: folder.spotFile("w"))

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["W names plain, which has no on= line, so it never prints a value. Give plain an event, such as on=clock.60."])
    }

    func testAnEventThatNoSpotRaisesIsAFaultThatNamesTheFix() async throws {
        try "#!/bin/sh\n# on=music.track\n# on=clipboard.change\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile("song"))

        let alone = await SpotCheck(folder: SpotsFolder(url: folder)).findings()
        try "#!/bin/sh\n# emits=music.track\n".writeScript(to: folder.spotFile("player"))
        let named = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(alone.map(\.fault), ["Song reads on music.track, which Openspot does not raise and no spot names in its emits. Add emits=music.track to the spot that raises it, or fix the name"])
        XCTAssertEqual(named, [])
    }

    func testASpotThatReadsOnTheEventItRaisesIsWarned() async throws {
        try "#!/bin/sh\n# title=Song\n# on=music.track\n# emits=music.track\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile("song"))

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["Song reads on music.track and raises it, so a raise from its read would read it again without end. Raise it from an action, or rename one of them"])
    }

    func testNoFaultIsAnEmptyList() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: folder.spotFile("hello"))

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(SpotCheck.json(findings), "[]\n")
    }

    func testAStoppedCheckRunsNoMoreReads() async throws {
        let started = folder.appendingPathComponent("started")
        let far = folder.appendingPathComponent("far")
        let body = "if [ -f '\(started.path)' ]; then touch '\(far.path)'; fi; touch '\(started.path)'; sleep 30"
        try "#!/bin/sh\n# on=sheet.open\n\(body)\n".writeScript(to: folder.spotFile("first"))
        try "#!/bin/sh\n# on=sheet.open\n\(body)\n".writeScript(to: folder.spotFile("second"))
        let check = Task { await SpotCheck(folder: SpotsFolder(url: folder), timeout: 60).findings() }
        for _ in 0..<1000 {
            if FileManager.default.fileExists(atPath: started.path) { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        check.cancel()
        _ = await check.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: far.path))
    }

    func testARowThatPushesAPageThatNoSpotTakesIsAFaultThatNamesThePagesLine() async throws {
        try "#!/bin/sh\n# pages=text:*\n".writeScript(to: folder.spotFile("translate"))
        let file = folder.spotFile("clips")
        try "#!/bin/sh\n# on=sheet.open\nprintf 'row=a\\npush=text:a\\npush.spot=translate\\n\\nrow=b\\npush=word:b\\npush.spot=translate\\n\\nrow=c\\npush=true\\n'\n".writeScript(to: file)

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the row b pushes the page word:b of translate, which takes no such page. Add pages=word:* to translate",
            "the row c pushes the page c of clips, which takes no such page. Add pages=c to clips",
        ])
    }

    func testAReadThatPushesOrAFrameWithBothMovesIsAFault() async throws {
        try "#!/bin/sh\n# on=sheet.open\n# pages=*\nprintf 'push=a\\npop=true\\n\\nrow=r\\n'\n".writeScript(to: folder.spotFile("both"))
        try "#!/bin/sh\n# on=sheet.open\n# pages=*\nprintf 'push=a\\n\\nrow=r\\n'\n".writeScript(to: folder.spotFile("reads"))

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.line), [
            "both: the frame holds both push and pop, and moves nothing. Print one of them",
            "reads: the read prints push, which moves nothing in a read. Print it from a press",
        ])
    }
}
