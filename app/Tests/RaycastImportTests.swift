import XCTest
@testable import OpenspotCore

@MainActor
final class RaycastImportTests: XCTestCase {
    private var root: URL!
    private var scripts: URL!
    private var spots: URL!

    override func setUpWithError() throws {
        root = try temporaryFolder()
        scripts = root.appendingPathComponent(".config/raycast/script-commands", isDirectory: true)
        spots = root.appendingPathComponent(".config/openspot/spots", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.appendingPathComponent(".config/openspot").path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": root.appendingPathComponent("core").path, "PWD": root.path, "PATH": "/usr/bin:/bin"]
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: Mac(), places: .test(environment), rates: .offline).work(for: call, request: .test(arguments, in: environment), input: { "" }))
        return await work()
    }

    private func script(_ name: String, header: [String], body: String) throws {
        let file = scripts.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (["#!/bin/sh", "# @raycast.schemaVersion 1"] + header.map { "# @raycast.\($0)" } + [body]).joined(separator: "\n").writeScript(to: file)
    }

    private func imported() async throws -> [String] {
        let answer = try await answer(["import", "raycast", scripts.path, "--json"])
        XCTAssertEqual(answer.code, 0, answer.errors)
        let items = try JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]] ?? []
        return items.map { "\($0["outcome"] ?? "") \($0["id"] ?? $0["file"] ?? "")" }
    }

    private func spot(_ id: String) throws -> Spot {
        try XCTUnwrap(SpotsFolder(url: spots).scan().scripts.first { $0.id == id })
    }

    private func run(_ id: String, _ arguments: [String], input: String? = nil) async throws -> (frames: [String], end: TerminalRun.End) {
        var frames: [String] = []
        let end = await TerminalRun(spot: try spot(id), arguments: arguments, input: input).start { frames.append($0) }
        return (frames, end)
    }

    func testEachScriptCommandBecomesASpotThatLoadsAndOthersAreSkipped() async throws {
        try script("hello.sh", header: ["title Say Hello", "mode compact", "icon 👋", "packageName Greetings"], body: "echo hello")
        try script("dashboard/weather.sh", header: ["title Current Weather", "mode inline", "refreshTime 5m"], body: "echo sunny")
        try script("notes.template.sh", header: ["title Notes", "mode silent"], body: "")
        try "#!/bin/sh\necho plain\n".writeScript(to: scripts.appendingPathComponent("plain.sh"))
        try "# @raycast.title Readme\n".write(to: scripts.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let items = try await imported()

        XCTAssertEqual(items, ["added current-weather", "added say-hello", "skipped notes.template.sh", "skipped plain.sh", "skipped README.md"])
        XCTAssertEqual(try SpotsFolder(url: spots).scan().spots.map(\.id).sorted(), ["current-weather", "say-hello"])
        XCTAssertEqual(try spot("say-hello").name, "Say Hello")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spots.appendingPathComponent("say-hello.spot/raycast/hello.sh").path))
    }

    func testAScriptImportedBeforeIsKeptAndANameThatAnotherSpotHasTakesANumber() async throws {
        try script("hello.sh", header: ["title Coffee", "mode compact"], body: "echo hello")
        try TestSpot(header: "", body: "echo mine").write(to: spots.spotFile("coffee"))

        let first = try await imported()
        let second = try await imported()

        XCTAssertEqual(first, ["added coffee-2"])
        XCTAssertEqual(second, ["kept coffee-2"])
    }

    func testADryRunChangesNothing() async throws {
        try script("hello.sh", header: ["title Say Hello", "mode compact"], body: "echo hello")

        let answer = try await answer(["import", "raycast", scripts.path, "--dry-run"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.contains("row=say-hello\ntitle=Say Hello\ndetail=added"), answer.output)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
    }

    func testAMissingFolderFailsWithItsPath() async throws {
        let answer = try await answer(["import", "raycast", root.appendingPathComponent("nowhere").path])

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("nowhere"), answer.errors)
    }

    func testACompactScriptShowsItsLastLineAsAToastWithNoColourCodes() async throws {
        try script("hello.sh", header: ["title Say Hello", "mode compact"], body: "echo first\nprintf '\\033[31mred\\033[0m\\n\\n'")
        _ = try await imported()

        let run = try await run("say-hello", ["open"])

        XCTAssertEqual(run.end.code, 0, run.end.errors)
        XCTAssertEqual(run.frames, ["toast=red\n"])
    }

    func testAScriptRunsInTheFolderItCameFrom() async throws {
        try script("where.sh", header: ["title Where", "mode compact"], body: "pwd")
        _ = try await imported()

        let run = try await run("where", ["open"])

        XCTAssertEqual(run.frames, ["toast=\(scripts.path)\n"])
    }

    func testAFailedScriptShowsItsLastLineAndItsCode() async throws {
        try script("broken.sh", header: ["title Broken", "mode compact"], body: "echo 'Invalid value provided'\nexit 3")
        _ = try await imported()

        let run = try await run("broken", ["open"])

        XCTAssertEqual(run.end.code, 3)
        XCTAssertEqual(run.end.errors, "Invalid value provided\n")
    }

    func testASpotWithAnArgumentAsksForItAndPassesItEncoded() async throws {
        try script("search.sh", header: ["title Search Flights", "mode silent", #"argument1 { "type": "text", "placeholder": "from city", "percentEncoded": true }"#, #"argument2 { "type": "text", "placeholder": "to city", "optional": true }"#], body: "echo \"$1|$2\"")
        _ = try await imported()

        let read = try await run("search-flights", ["read"], input: "search=New York\n")
        let split = try await run("search-flights", ["read"], input: "search=Kyiv  Rome di Roma\n")
        let ran = try await run("search-flights", ["run"], input: "arg1=New York\narg2=Rome\n")
        let empty = try await run("search-flights", ["run"], input: "arg2=Rome\n")

        XCTAssertTrue(read.frames.joined().contains("field=arg1\ntitle=from city\nplaceholder=from city\ngrow=false\nvalue=New\n"), read.frames.joined())
        XCTAssertTrue(split.frames.joined().contains("value=Kyiv\n"), split.frames.joined())
        XCTAssertTrue(split.frames.joined().contains("field=arg2\ntitle=to city\nplaceholder=to city\ngrow=false\nvalue=Rome di Roma\n"), split.frames.joined())
        XCTAssertTrue(read.frames.joined().hasPrefix("search=off\ngrid=arg1\ngrid=arg2\ngrid=run\n"), read.frames.joined())
        XCTAssertTrue(read.frames.joined().contains("button=run\ntitle=Run\nlook=strong\nshortcut=return\nscope=spot\nclose=true\n"), read.frames.joined())
        XCTAssertEqual(ran.frames, ["toast=New%20York|Rome\n"])
        XCTAssertEqual(empty.end.code, 1)
        XCTAssertEqual(empty.end.errors, "Fill in from city.\n")
    }

    func testADropdownShowsAChoiceAndPassesTheValueOfThePickedOption() async throws {
        try script("dock.sh", header: ["title Dock Position", "mode compact", #"argument1 { "type": "dropdown", "placeholder": "Position", "data": [{"title": "Left", "value": "left"}, {"title": "Right", "value": "right"}] }"#], body: "echo \"dock $1\"")
        _ = try await imported()

        let read = try await run("dock-position", ["read"], input: "search=Right\n")
        let ran = try await run("dock-position", ["run"], input: "arg1=2\n")

        XCTAssertTrue(read.frames.joined().contains("choice=arg1\ntitle=Position\nvalue=2\n\noption=1\ntitle=Left\n\noption=2\ntitle=Right\n"), read.frames.joined())
        XCTAssertEqual(ran.frames, ["toast=dock right\n"])
    }

    func testAFullOutputScriptRunsWhenItsSheetOpensAndShowsAllItsOutput() async throws {
        try script("info.sh", header: ["title Network Info", "mode fullOutput"], body: "echo one\necho two")
        _ = try await imported()

        let read = try await run("network-info", ["read"])

        XCTAssertEqual(read.frames.count, 2)
        XCTAssertTrue(read.frames[0].contains("value=Running…"), read.frames[0])
        XCTAssertTrue(read.frames[1].contains("field=output\ntype=multiline\nreadonly=true\nvalue=one\\ntwo\n"), read.frames[1])
        XCTAssertTrue(read.frames[1].contains("button=run\ntitle=Run Again\nshortcut=cmd+r\n"), read.frames[1])
        XCTAssertTrue(read.frames[1].hasPrefix("search=off\ngrid=output\n"), read.frames[1])
    }

    func testAnInlineScriptShowsItsFirstLineOnItsCardAndInTheMenuBar() async throws {
        try script("weather.sh", header: ["title Current Weather", "mode inline", "refreshTime 1m"], body: "echo 'Sunny 21°'\necho more")
        _ = try await imported()

        let read = try await run("current-weather", ["read"])
        let text = try String(contentsOf: spots.appendingPathComponent("current-weather.spot/current-weather.sh"), encoding: .utf8)

        XCTAssertEqual(read.frames, ["detail=Sunny 21°\n\ntext=output\ntitle=Sunny 21°\n"])
        XCTAssertTrue(text.contains("# on=panel.open\n# on=clock.60\n# offers=card\n# offers=menubar\n"), text)
    }

    func testAScriptThatNeedsConfirmationAsksTwice() async throws {
        try script("trash.sh", header: ["title Move Desktop to Trash", "mode silent", "needsConfirmation true"], body: "echo moved")
        _ = try await imported()

        let text = try String(contentsOf: spots.appendingPathComponent("move-desktop-to-trash.spot/move-desktop-to-trash.sh"), encoding: .utf8)
        let run = try await run("move-desktop-to-trash", ["run"])

        XCTAssertTrue(text.contains("# button=run\n# title=Move Desktop to Trash\n# confirm=Press again to run Move Desktop to Trash\n"), text)
        XCTAssertEqual(run.frames, ["toast=moved\n"])
    }

    func testAnImageIconNextToTheScriptIsCopiedIntoTheSpot() async throws {
        try script("light.sh", header: ["title Key Light", "mode silent", "icon images/light.png"], body: "true")
        try FileManager.default.createDirectory(at: scripts.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: scripts.appendingPathComponent("images/light.png"))
        _ = try await imported()

        let text = try String(contentsOf: spots.appendingPathComponent("key-light.spot/key-light.sh"), encoding: .utf8)

        XCTAssertTrue(text.contains("# icon=icon.png\n"), text)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("key-light.spot/icon.png").path))
    }

    func testAFileThatAScriptLoadsFromItsFolderIsCopiedBesideIt() async throws {
        try script("vpn/vpn-start.sh", header: ["title VPN Start", "mode compact"], body: ". \"$(dirname \"$0\")/vpn-config.sh\"\necho \"start $server\"")
        try "server=home\n".write(to: scripts.appendingPathComponent("vpn/vpn-config.sh"), atomically: true, encoding: .utf8)
        try "# VPN\n".write(to: scripts.appendingPathComponent("vpn/README.md"), atomically: true, encoding: .utf8)
        _ = try await imported()
        try FileManager.default.removeItem(at: scripts)

        let run = try await run("vpn-start", ["open"])

        XCTAssertEqual(run.frames, ["toast=start home\n"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("vpn-start.spot/raycast/README.md").path))
    }

    func testANameOfASpotThatComesWithOpenspotTakesANumber() async throws {
        try "#!/bin/sh\n# title=Clock\n".writeScript(to: root.appendingPathComponent("core/clock.spot/clock.sh"))
        try script("clock.sh", header: ["title Clock", "mode compact"], body: "date")

        let items = try await imported()

        XCTAssertEqual(items, ["added clock-2"])
    }

    func testTheTextOfASlashCommandGoesWholeToASingleArgument() async throws {
        try script("shout.sh", header: ["title Shout", "mode compact", #"argument1 { "type": "text", "placeholder": "Text" }"#], body: "echo \"$1\"")
        _ = try await imported()

        let read = try await run("shout", ["read"], input: "search=hello  big world\n")

        XCTAssertTrue(read.frames.joined().contains("grow=false\nvalue=hello  big world\n"), read.frames.joined())
    }

    func testASlashCommandThatFillsEachRequiredArgumentAsksOpenspotToRunAtOnce() async throws {
        try script("growth.sh", header: ["title Growth", "mode compact", #"argument1 { "type": "text", "placeholder": "From" }"#, #"argument2 { "type": "text", "placeholder": "To" }"#], body: "echo \"$1 $2\"")
        try script("wipe.sh", header: ["title Wipe", "mode silent", "needsConfirmation true", #"argument1 { "type": "text", "placeholder": "What" }"#], body: "echo wiped")
        _ = try await imported()

        let full = try await run("growth", ["read"], input: "search=3000 4000\n")
        let short = try await run("growth", ["read"], input: "search=3000\n")
        let none = try await run("growth", ["read"])
        let confirms = try await run("wipe", ["read"], input: "search=desktop\n")

        XCTAssertTrue(full.frames.joined().hasPrefix("search=off\ngrid=arg1\ngrid=arg2\ngrid=run\nslash=run\n"), full.frames.joined())
        XCTAssertFalse(short.frames.joined().contains("slash=run"), short.frames.joined())
        XCTAssertFalse(none.frames.joined().contains("slash=run"), none.frames.joined())
        XCTAssertFalse(confirms.frames.joined().contains("slash=run"), confirms.frames.joined())
    }

    func testAScriptLeftOutIsNotImported() async throws {
        try script("hello.sh", header: ["title Say Hello", "mode compact"], body: "echo hello")
        try script("dashboard/weather.sh", header: ["title Current Weather", "mode compact"], body: "echo sunny")

        let answer = try await answer(["import", "raycast", scripts.path, "--skip", "dashboard/weather.sh", "--json"])
        let items = try JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: Any]] ?? []

        XCTAssertEqual(items.map { "\($0["outcome"] ?? "") \($0["reason"] ?? "")" }, ["skipped Left out", "added "])
        XCTAssertEqual(try SpotsFolder(url: spots).scan().spots.map(\.id), ["say-hello"])
    }
}
