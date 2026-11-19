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

    private var calls: URL {
        root.appendingPathComponent("calls")
    }

    private func run(_ id: String, _ arguments: [String], input: String? = nil) async throws -> (frames: [String], end: TerminalRun.End) {
        let tools = root.appendingPathComponent("tools")
        try "#!/bin/sh\necho \"$*\" >> '\(calls.path)'\n".writeScript(to: tools.appendingPathComponent("openspot"))
        let environment = TestEnvironment.values.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new }
        var frames: [String] = []
        let end = await TerminalRun(spot: try spot(id), arguments: arguments, input: input, careful: nil, callers: nil, environment: environment, folder: nil).start { frames.append($0) }
        return (frames, end)
    }

    private func toasts() throws -> [String] {
        guard FileManager.default.fileExists(atPath: calls.path) else { return [] }
        return try String(contentsOf: calls, encoding: .utf8).split(separator: "\n").filter { $0.hasPrefix("toast ") }.map { String($0.dropFirst(6)) }
    }

    private func manifest(_ id: String) throws -> String {
        try String(contentsOf: spots.appendingPathComponent("\(id).spot/spot.toml"), encoding: .utf8)
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
        try TestSpot(toml: "", body: "echo mine").write(to: spots.spotFile("coffee"))

        let first = try await imported()
        let second = try await imported()

        XCTAssertEqual(first, ["added coffee-2"])
        XCTAssertEqual(second, ["kept coffee-2"])
    }

    func testADryRunChangesNothing() async throws {
        try script("hello.sh", header: ["title Say Hello", "mode compact"], body: "echo hello")

        let answer = try await answer(["import", "raycast", scripts.path, "--dry-run"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.contains("text=say-hello\ntitle=Say Hello\ndetail=added"), answer.output)
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

        let run = try await run("say-hello", ["run"])

        XCTAssertEqual(run.end.code, 0, run.end.errors)
        XCTAssertEqual(try toasts(), ["red"])
    }

    func testAScriptRunsInTheFolderItCameFrom() async throws {
        try script("where.sh", header: ["title Where", "mode compact"], body: "pwd")
        _ = try await imported()

        _ = try await run("where", ["run"])

        XCTAssertEqual(try toasts(), [scripts.path])
    }

    func testAFailedScriptShowsItsLastLineAndItsCode() async throws {
        try script("broken.sh", header: ["title Broken", "mode compact"], body: "echo 'Invalid value provided'\nexit 3")
        _ = try await imported()

        let run = try await run("broken", ["run"])

        XCTAssertEqual(run.end.code, 3)
        XCTAssertEqual(run.end.errors, "Invalid value provided\n")
    }

    func testASpotWithAnArgumentAsksForItAndPassesItEncoded() async throws {
        try script("search.sh", header: ["title Search Flights", "mode silent", #"argument1 { "type": "text", "placeholder": "from city", "percentEncoded": true }"#, #"argument2 { "type": "text", "placeholder": "to city", "optional": true }"#], body: "echo \"$1|$2\"")
        _ = try await imported()

        let read = try await run("search-flights", ["show"], input: "search=New York\n")
        let split = try await run("search-flights", ["show"], input: "search=Kyiv  Rome di Roma\n")
        let ran = try await run("search-flights", ["run"], input: "input.arg1=New York\ninput.arg2=Rome\n")
        let empty = try await run("search-flights", ["run"], input: "input.arg2=Rome\n")

        XCTAssertTrue(read.frames.joined().contains("field=arg1\ntitle=from city\nplaceholder=from city\ngrow=false\nvalue=New\n"), read.frames.joined())
        XCTAssertTrue(split.frames.joined().contains("value=Kyiv\n"), split.frames.joined())
        XCTAssertTrue(split.frames.joined().contains("field=arg2\ntitle=to city\nplaceholder=to city\ngrow=false\nvalue=Rome di Roma\n"), split.frames.joined())
        XCTAssertTrue(read.frames.joined().hasPrefix("frame=\ngrid=arg1\ngrid=arg2\ngrid=run\n"), read.frames.joined())
        XCTAssertTrue(read.frames.joined().contains("button=run\ntitle=Run\nlook=strong\nshortcut=return\nscope=spot\n"), read.frames.joined())
        XCTAssertEqual(ran.end.code, 0, ran.end.errors)
        XCTAssertEqual(try toasts(), ["New%20York|Rome"])
        XCTAssertEqual(empty.end.code, 1)
        XCTAssertEqual(empty.end.errors, "Fill in from city.\n")
    }

    func testADropdownShowsAChoiceAndPassesTheValueOfThePickedOption() async throws {
        try script("dock.sh", header: ["title Dock Position", "mode compact", #"argument1 { "type": "dropdown", "placeholder": "Position", "data": [{"title": "Left", "value": "left"}, {"title": "Right", "value": "right"}] }"#], body: "echo \"dock $1\"")
        _ = try await imported()

        let read = try await run("dock-position", ["show"], input: "search=Right\n")
        let ran = try await run("dock-position", ["run"], input: "input.arg1=2\n")

        XCTAssertTrue(read.frames.joined().contains("choice=arg1\ntitle=Position\nvalue=2\n\noption=1\ntitle=Left\n\noption=2\ntitle=Right\n"), read.frames.joined())
        XCTAssertEqual(try toasts(), ["dock right"])
    }

    func testAFullOutputScriptRunsWhenItsSheetOpensAndShowsAllItsOutput() async throws {
        try script("info.sh", header: ["title Network Info", "mode fullOutput"], body: "echo one\necho two")
        _ = try await imported()

        let read = try await run("network-info", ["show"])

        XCTAssertEqual(read.frames.count, 2)
        XCTAssertTrue(read.frames[0].contains("value=Running…"), read.frames[0])
        XCTAssertTrue(read.frames[1].contains("field=output\ntype=multiline\nreadonly=true\nvalue=one\\ntwo\n"), read.frames[1])
        XCTAssertTrue(read.frames[1].contains("button=run\ntitle=Run Again\nshortcut=cmd+r\n"), read.frames[1])
        XCTAssertTrue(read.frames[1].hasPrefix("frame=\ngrid=output\n"), read.frames[1])
    }

    func testAnInlineScriptShowsItsFirstLineOnItsCardAndInTheMenuBar() async throws {
        try script("weather.sh", header: ["title Current Weather", "mode inline", "refreshTime 1m"], body: "echo 'Sunny 21°'\necho more")
        _ = try await imported()

        let read = try await run("current-weather", ["show"])
        let manifest = try manifest("current-weather")

        XCTAssertEqual(read.frames, ["frame=\ngrid.bar=output\ndetail=Sunny 21°\n\ntext=output\ntitle=Sunny 21°\n"])
        XCTAssertTrue(manifest.contains("on = [\"panel.open\", \"clock.60\"]"), manifest)
    }

    func testAScriptThatNeedsConfirmationAsksTwice() async throws {
        try script("trash.sh", header: ["title Move Desktop to Trash", "mode silent", "needsConfirmation true"], body: "echo moved")
        _ = try await imported()

        let manifest = try manifest("move-desktop-to-trash")
        _ = try await run("move-desktop-to-trash", ["run"])

        XCTAssertTrue(manifest.contains("[commands.run]\ntitle = \"Move Desktop to Trash\"\nconfirm = \"Press again to run Move Desktop to Trash\"\n"), manifest)
        XCTAssertEqual(try toasts(), ["moved"])
    }

    func testAnImageIconNextToTheScriptIsCopiedIntoTheSpot() async throws {
        try script("light.sh", header: ["title Key Light", "mode silent", "icon images/light.png"], body: "true")
        try FileManager.default.createDirectory(at: scripts.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: scripts.appendingPathComponent("images/light.png"))
        _ = try await imported()

        let manifest = try manifest("key-light")

        XCTAssertTrue(manifest.contains("icon = \"icon.png\"\n"), manifest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("key-light.spot/icon.png").path))
    }

    func testAFileThatAScriptLoadsFromItsFolderIsCopiedBesideIt() async throws {
        try script("vpn/vpn-start.sh", header: ["title VPN Start", "mode compact"], body: ". \"$(dirname \"$0\")/vpn-config.sh\"\necho \"start $server\"")
        try "server=home\n".write(to: scripts.appendingPathComponent("vpn/vpn-config.sh"), atomically: true, encoding: .utf8)
        try "# VPN\n".write(to: scripts.appendingPathComponent("vpn/README.md"), atomically: true, encoding: .utf8)
        _ = try await imported()
        try FileManager.default.removeItem(at: scripts)

        _ = try await run("vpn-start", ["run"])

        XCTAssertEqual(try toasts(), ["start home"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("vpn-start.spot/raycast/README.md").path))
    }

    func testANameOfASpotThatComesWithOpenspotTakesANumber() async throws {
        try "#!/bin/sh\n".writeScript(to: root.appendingPathComponent("core/clock.spot/clock.sh"))
        try "title = 'Clock'\n".write(to: root.appendingPathComponent("core/clock.spot/spot.toml"), atomically: true, encoding: .utf8)
        try script("clock.sh", header: ["title Clock", "mode compact"], body: "date")

        let items = try await imported()

        XCTAssertEqual(items, ["added clock-2"])
    }

    func testTheTextOfASlashCommandGoesWholeToASingleArgument() async throws {
        try script("shout.sh", header: ["title Shout", "mode compact", #"argument1 { "type": "text", "placeholder": "Text" }"#], body: "echo \"$1\"")
        _ = try await imported()

        let read = try await run("shout", ["show"], input: "search=hello  big world\n")

        XCTAssertTrue(read.frames.joined().contains("grow=false\nvalue=hello  big world\n"), read.frames.joined())
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
