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
        try "#!/bin/sh\necho\n".writeScript(to: file, toml: "answers = 'huge'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings, [SpotCheck.Finding(spot: "weather", file: file.path, fault: "Weather has an unknown answers: huge. Use answers = \"last\" or answers = \"card\"")])
        let json = try JSONSerialization.jsonObject(with: Data(SpotCheck.json(findings).utf8)) as? [[String: String]]
        XCTAssertEqual(json, [["spot": "weather", "file": file.path, "fault": "Weather has an unknown answers: huge. Use answers = \"last\" or answers = \"card\""]])
    }

    func testTheTestsOfASpotAreNotCheckedAsASpot() async throws {
        try "#!/bin/sh\necho item=a\necho title=A\n".writeScript(to: folder.spotFile("notes"), toml: "")
        try "#!/bin/sh\nexit 1\n".writeScript(to: folder.appendingPathComponent("notes.spot/tests/run.sh"), toml: "answers = 'huge'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings, [])
    }

    func testAValueWithANewLinePrintedByHandIsAFaultThatNamesTheHelper() async throws {
        let file = folder.spotFile("notes")
        try "#!/bin/sh\nprintf 'item=a\\ntitle=one\\ntwo\\n\\nitem=b\\ntitle=B\\ntitle=C\\n'\n".writeScript(to: file, toml: "")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the block item=a has a line with no =, as a value with a new line prints. Print each value from data with openspot_kv, openspot_item or esc",
            "the block item=b has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_item or esc"
        ])
    }

    func testACheckRunsTheShowOfASpotWithASheetAndNotOfASpotWithCommandsAndNoEvents() async throws {
        let notes = folder.spotFile("notes")
        try "#!/bin/sh\nprintf 'item=a\\ntitle=one\\ntwo\\n'\n".writeScript(to: notes, toml: "title = 'Notes'")
        try "#!/bin/sh\nprintf 'item=a\\ntitle=one\\ntwo\\n'\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.spot), ["notes"])
    }

    func testAnItemOrAnActionCannotTakeTheNameOfAHandler() async throws {
        try "#!/bin/sh\nprintf 'item=search\\ntitle=Search\\n'\n".writeScript(to: folder.spotFile("bills"), toml: "title = 'Bills'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("tabs"), toml: "title = 'Tabs'\n\n[actions.show]\ntitle = 'Show'")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map { "\($0.spot ?? ""): \($0.fault)" }.sorted(), [
            "bills: an item cannot be called search",
            "tabs: Tabs has [actions.show], which takes the name of a handler that its [on] calls. Give the action another ID"
        ])
    }

    func testAnEventThatNoBindingNamesIsAFaultThatNamesTheFix() async throws {
        try "#!/bin/sh\nprintf 'item=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile("song"), toml: "[on]\n\"music.track\" = true\n\"clipboard.change\" = true")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["Song has [on] music.track, which names no binding music. Add it to [bindings], such as music = { spot = \"<id>\" }"])
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
        try "#!/bin/sh\n\(body)\n".writeScript(to: folder.spotFile("first"), toml: "")
        try "#!/bin/sh\n\(body)\n".writeScript(to: folder.spotFile("second"), toml: "")
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
        try "#!/bin/sh\nprintf 'item=a\\nroute=text:a\\n\\nitem=c\\nroute=c\\n'\n".writeScript(to: file, toml: "pages = ['text:*']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), [
            "the row c pushes the page c of clips, which takes no such page. Add pages = [\"c\"] to clips",
        ])
    }

    func testAnEffectInTheRootIsAnUnknownKeyThatACheckReports() async throws {
        let root = "frame=\\ntoast=Saved\\nlink=https://a.b\\nselect=r\\npush=a\\npush.title=A\\npush.spot=b\\npush.replace=true\\npop=true\\n"
        try "#!/bin/sh\nprintf '\(root)\\nitem=r\\n'\n".writeScript(to: folder.spotFile("old"), toml: "pages = ['*']")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["toast", "link", "select", "push", "push.title", "push.spot", "push.replace", "pop"].map { "the root has an unknown key: \($0)" })
    }

    func testABlockThatStartsWithAnEffectIsAnItemThatACheckCannotRead() async throws {
        try "#!/bin/sh\nprintf 'toast=Saved\\n\\npop=true\\n\\nitem=r\\n'\n".writeScript(to: folder.spotFile("old"), toml: "")

        let findings = await SpotCheck(folder: SpotsFolder(url: folder)).findings()

        XCTAssertEqual(findings.map(\.fault), ["cannot read the item toast=Saved", "cannot read the item pop=true"])
    }

    func testAViewNamedLikeAKindOfBlockIsReported() async throws {
        let file = folder.spotFile("meter")
        try "#!/bin/sh\n".writeScript(to: file, toml: "views = ['text.swift', 'dial.swift']")
        for name in ["text.swift", "dial.swift"] {
            try Data("struct SpotView {}\n".utf8).write(to: file.deletingLastPathComponent().appendingPathComponent(name))
        }
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\nexit 0\n".writeScript(to: tools.appendingPathComponent("xcode-select"))
        try "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -o ] && printf built > \"$2\"; shift; done\n".writeScript(to: tools.appendingPathComponent("swiftc"))
        try "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -output ] && printf both > \"$2\"; shift; done\n".writeScript(to: tools.appendingPathComponent("lipo"))
        let views = ViewLibrary(cache: folder.appendingPathComponent("cache"), tools: tools)

        let findings = await SpotCheck(folder: SpotsFolder(url: folder), views: views).findings()

        XCTAssertEqual(findings.map(\.fault), ["the view text.swift has the name of the kind text, so a text block never reaches it. Rename the file"])
    }
}
