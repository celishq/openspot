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
        try "#!/bin/sh\necho\n".writeScript(to: file, toml: "mode = 'huge'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings, [SpotCheck.Finding(spot: "weather", file: file.path, fault: "Weather has an unknown mode: huge. Use once or stay")])
        let json = try JSONSerialization.jsonObject(with: Data(SpotCheck.json(findings).utf8)) as? [[String: String]]
        XCTAssertEqual(json, [["spot": "weather", "file": file.path, "fault": "Weather has an unknown mode: huge. Use once or stay"]])
    }

    func testTheTestsOfASpotAreNotCheckedAsASpot() async throws {
        try "#!/bin/sh\necho text=a\necho title=A\n".writeScript(to: folder.spotFile("notes"), toml: "on = ['sheet.open']")
        try "#!/bin/sh\nexit 1\n".writeScript(to: folder.appendingPathComponent("notes.spot/tests/run.sh"), toml: "mode = 'huge'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings, [])
    }

    func testAValueWithANewLinePrintedByHandIsAFaultThatNamesTheHelper() async throws {
        let file = folder.spotFile("notes")
        try "#!/bin/sh\nprintf 'text=a\\ntitle=one\\ntwo\\n\\ntext=b\\ntitle=B\\ntitle=C\\n'\n".writeScript(to: file, toml: "on = ['sheet.open']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the block text=a has a line with no =, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc",
            "the block text=b has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        ])
    }

    func testAnEventThatNoSpotRaisesIsAFaultThatNamesTheFix() async throws {
        try "#!/bin/sh\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile("song"), toml: "on = ['music.track', 'clipboard.change']")

        let alone = await SpotCheck(folder: SpotsFolder(url: folder)).findings()
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("player"), toml: "emits = ['music.track']")
        let named = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(alone.map(\.fault), ["Song reads on music.track, which Openspot does not raise and no spot names in its emits. Add emits = [\"music.track\"] to the spot that raises it, or fix the name"])
        XCTAssertEqual(named, [])
    }

    func testASpotThatReadsOnTheEventItRaisesIsWarned() async throws {
        try "#!/bin/sh\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile("song"), toml: "title = 'Song'\non = ['music.track']\nemits = ['music.track']")

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
        try "#!/bin/sh\n\(body)\n".writeScript(to: folder.spotFile("first"), toml: "on = ['sheet.open']")
        try "#!/bin/sh\n\(body)\n".writeScript(to: folder.spotFile("second"), toml: "on = ['sheet.open']")
        let check = Task { await SpotCheck(folder: SpotsFolder(url: folder), timeout: 60).findings() }
        for _ in 0..<6000 {
            if FileManager.default.fileExists(atPath: started.path) { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        check.cancel()
        _ = await check.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: far.path))
    }

    func testARowWithARouteThatTheSpotDoesNotTakeIsAFaultThatNamesThePagesLine() async throws {
        let file = folder.spotFile("clips")
        try "#!/bin/sh\nprintf 'text=a\\nroute=text:a\\n\\ntext=c\\nroute=c\\n'\n".writeScript(to: file, toml: "on = ['sheet.open']\npages = ['text:*']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the row c pushes the page c of clips, which takes no such page. Add pages = [\"c\"] to clips",
        ])
    }

    func testAnEffectInTheRootIsAnUnknownKeyThatACheckReports() async throws {
        let root = "frame=\\ntoast=Saved\\nlink=https://a.b\\nselect=r\\npush=a\\npush.title=A\\npush.spot=b\\npush.replace=true\\npop=true\\n"
        try "#!/bin/sh\nprintf '\(root)\\ntext=r\\n'\n".writeScript(to: folder.spotFile("old"), toml: "on = ['sheet.open']\npages = ['*']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["toast", "link", "select", "push", "push.title", "push.spot", "push.replace", "pop"].map { "the root has an unknown key: \($0)" })
    }

    func testABlockThatStartsWithAnEffectIsAnItemThatACheckCannotRead() async throws {
        try "#!/bin/sh\nprintf 'toast=Saved\\n\\npop=true\\n\\ntext=r\\n'\n".writeScript(to: folder.spotFile("old"), toml: "on = ['sheet.open']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["cannot read the item toast=Saved", "cannot read the item pop=true"])
    }
}
