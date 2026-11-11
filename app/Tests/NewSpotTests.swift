import XCTest
@testable import OpenspotCore

/// Proves the New spot sheet: it copies a prompt for an agent or makes a working starter, and the guide that it opens
/// teaches a spot that works.
final class NewSpotTests: XCTestCase {
    private var folder: URL!
    private var plugins: URL!
    private var tools: URL!
    private var guideText = ""
    private var guideURL: URL!
    private var root: URL!
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-new-\(UUID().uuidString)")
        plugins = folder.appendingPathComponent("plugins")
        tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        guideURL = folder.appendingPathComponent("GUIDE.md")
        guideText = try joinedSpecs()
        try guideText.write(to: guideURL, atomically: true, encoding: .utf8)
        for (name, script) in [("pbcopy", "cat > '\(folder.path)/clipboard'"), ("open", "echo \"$@\" > '\(folder.path)/opened'")] {
            try "#!/bin/sh\n\(script)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
    }

    override func tearDownWithError() throws {
        if let path { setenv("PATH", path, 1) }
        try FileManager.default.removeItem(at: folder)
    }

    /// The New spot sheet of this test's plugins folder.
    private func newSpot() throws -> Spot {
        let config = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let spots = ShippedSpot.commands(folder: plugins, guide: guideURL, app: "/Apps/Openspot.app/Contents/MacOS/Openspot", config: config)
        return try XCTUnwrap(spots.first { $0.id == ShippedSpot.newID })
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    private func sheet(of spot: Spot) async throws -> SheetParts {
        let output = try await spot.items(timeout: 5)
        return try XCTUnwrap(SheetParts(output: output))
    }

    func testTheSpotsSpotShowsWithAnEmptyFolder() throws {
        let shipped = ShippedSpot.commands(folder: plugins, guide: guideURL, app: "")

        let scan = try PluginFolder(url: plugins).scan(shipped: shipped)

        XCTAssertTrue(scan.commands.contains { $0.id == ShippedSpot.spotsID })
        XCTAssertEqual(scan.refused, [])
    }

    func testTheSheetIsAListThatSearchesByScriptWithCopyPromptForAIFirstThenEachStarter() async throws {
        let output = try await newSpot().items(timeout: 5)

        XCTAssertEqual(output.search, .script)
        XCTAssertEqual(output.items.map(\.title), ["Copy prompt for AI"] + SpotStarter.allCases.map(\.title))
        XCTAssertEqual(output.items.first?.subtitle, "Type what the spot should do")
        XCTAssertTrue(Set(output.actions.map(\.id)).isSuperset(of: ["guide", "folder"]))
    }

    func testTheFirstRowShowsTheTextOfTheSearch() async throws {
        let output = try await newSpot().items(query: "Show the weather here", timeout: 5)

        XCTAssertEqual(output.items.first?.subtitle, "Show the weather here")
        XCTAssertEqual(output.items.count, 1 + SpotStarter.allCases.count)
    }

    func testCopyPromptForAICopiesThePromptWithTheSearchAndStartsNothing() async throws {
        let spot = try newSpot()

        let toast = try await spot.perform(.item(SpotItem(title: "Copy prompt for AI", run: "ask")), input: "search=Show the weather here\n", timeout: 5)

        XCTAssertEqual(toast, "Copied a prompt for your agent. Paste it into Claude Code, Codex or another agent.")
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.contains("Build an Openspot spot that does this: Show the weather here"))
        XCTAssertTrue(prompt.contains(plugins.path))
        XCTAssertTrue(prompt.contains("guide"))
        XCTAssertEqual(try PluginFolder(url: plugins).scan().commands, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("opened").path))
    }

    func testCopyPromptForAINeedsADescription() async throws {
        do {
            _ = try await newSpot().perform(.item(SpotItem(title: "Copy prompt for AI", run: "ask")), timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? PluginError)?.reason, "Type what the spot should do, then press `⏎`.")
        }
    }

    @MainActor
    func testWordsTypedJustBeforeEnterReachThePrompt() async throws {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: try newSpot())
        sheet.open {}
        for _ in 0..<500 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(10)) }

        sheet.search("Show the weather here")
        sheet.pick(try XCTUnwrap(sheet.list.shown.first))

        for _ in 0..<500 where (try? saved("clipboard"))?.contains("what the spot runs on my computer.") != true {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(try saved("clipboard").contains("Build an Openspot spot that does this: Show the weather here"))
    }

    func testAStarterMakesAWorkingSpotCalledUntitledAndOpensItsFile() async throws {
        let spot = try newSpot()

        _ = try await spot.perform(.item(SpotItem(title: "List", run: "list")), timeout: 5)
        _ = try await spot.perform(.item(SpotItem(title: "Button", run: "button")), timeout: 5)

        let names = try PluginFolder(url: plugins).scan().commands.map(\.id).sorted()
        XCTAssertEqual(names, ["untitled", "untitled-2"])
        XCTAssertEqual(try saved("opened"), "-t \(plugins.appendingPathComponent("untitled-2.sh").path)\n")
    }

    func testTheActionsOpenTheGuideAndTheFolder() async throws {
        let spot = try newSpot()

        _ = try await spot.perform(SpotAction(arguments: ["guide"]), timeout: 5)
        XCTAssertTrue(try saved("opened").contains("GUIDE.md"))

        _ = try await spot.perform(SpotAction(arguments: ["folder"]), timeout: 5)
        XCTAssertTrue(try saved("opened").contains(plugins.path))
    }

    /// The text of each block in the guide with this fence.
    private func blocks(_ fence: String) -> [String] {
        guideText.components(separatedBy: "```\(fence)\n").dropFirst().map { $0.components(separatedBy: "```")[0] }
    }

    func testEachExampleScriptInTheGuideLoadsAndAnswers() async throws {
        let scripts = blocks("sh")
        XCTAssertGreaterThan(scripts.count, 2)
        for (index, script) in scripts.enumerated() {
            let url = plugins.appendingPathComponent("example-\(index).sh")
            try script.writeScript(to: url)
        }

        let faults = await PluginCheck(folder: PluginFolder(url: plugins)).faults()

        XCTAssertEqual(faults, [])
    }

    func testTheGuideIsTheSpecsJoinedInOrder() throws {
        let out = folder.appendingPathComponent("built.md")
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = [root.appendingPathComponent("scripts/guide.sh").path, out.path]
        try script.run()
        script.waitUntilExit()

        XCTAssertEqual(script.terminationStatus, 0)
        XCTAssertTrue(try String(contentsOf: out, encoding: .utf8) == guideText)
        XCTAssertTrue(guideText.hasPrefix("# 01 Core"))
    }

    func testTheGuideTeachesNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "event=", "OPENSPOT_CONFIG", "openspot catalog"] {
            XCTAssertFalse(guideText.contains(old), old)
        }
    }

    /// The guide names each key that a part takes, and a part takes each key that the kinds table of the guide gives it.
    func testTheGuideAndThePartsTakeTheSameKeys() {
        let blocks = guideText.components(separatedBy: "## Blocks").dropFirst().first?.components(separatedBy: "## Drawings").first ?? ""
        for key in PartCatalog.keys {
            XCTAssertTrue(blocks.contains("`\(key)"), key)
        }
        for line in blocks.split(separator: "\n") where line.hasPrefix("| `") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            let kind = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            guard cells.count > 2, SpotPart.kinds.contains(kind) else { continue }
            for item in cells[2].components(separatedBy: ", ") {
                guard let word = item.split(separator: "`", omittingEmptySubsequences: false).dropFirst().first else { continue }
                XCTAssertTrue(PartCatalog.keys.contains(String(word.split(separator: "=").first ?? word)), "\(kind): \(word)")
            }
        }
    }

    func testTheWidgetExampleInTheReadmeLoads() throws {
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let example = try XCTUnwrap(readme.components(separatedBy: "```toml\n").dropFirst().first?.components(separatedBy: "```").first)
        let widgets = try XCTUnwrap(try TomlDocument(text: example).arrays["widgets"])
        guard case .strings(let grid)? = widgets.first?["grid"] else { return XCTFail("no grid") }

        XCTAssertNil(widgets.first?["places"])
        XCTAssertEqual(WidgetLayout(drawing: grid).names, ["memory", "battery", "cpu", "disk"])
    }

    /// The specs `00` to `99` of `spec/`, joined in order with one blank line between them.
    private func joinedSpecs() throws -> String {
        let specs = root.appendingPathComponent("spec")
        let names = try FileManager.default.contentsOfDirectory(atPath: specs.path).filter { $0.first?.isNumber == true && $0.hasSuffix(".md") }.sorted()
        return try names.map { try String(contentsOf: specs.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n")
    }

}
