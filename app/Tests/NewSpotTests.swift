import XCTest
@testable import OpenspotCore

/// Proves the New spot sheet: it copies a prompt for an agent or makes a working starter, and the guide that it opens
/// teaches a spot that works.
final class NewSpotTests: BuiltInCase {
    private var guideText = ""
    private var repo: URL {
        repoPlugins.deletingLastPathComponent()
    }

    override func setUp() async throws {
        try await super.setUp()
        guideText = try joinedSpecs()
        try guideText.write(to: guide, atomically: true, encoding: .utf8)
        try fake("pbcopy", "cat > '\(root.path)/direct'")
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "[ \"$1 $2\" = 'clipboard copy' ] && exec cat > '\(root.path)/clipboard'\nexec '\(real.path)' \"$@\"")
        try fake("open", "echo \"$@\" > '\(root.path)/opened'")
    }

    /// The New spot sheet of the app.
    private func newSpot() throws -> Spot {
        try spot("new")
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }

    func testItIsASmallListThatTheConfigOpensWithCommandN() throws {
        let spot = try newSpot()
        let defaults = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "New spot")
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(spot.size, .small)
        XCTAssertTrue(spot.isOnGrid)
        XCTAssertEqual(SpotArrangement().spot(openedBy: ActionKey(name: "n", isCommand: true), over: defaults.arrangement), spot.id)
    }

    func testTheSheetIsAListThatSearchesByScriptWithCopyPromptForAIFirstThenEachStarter() async throws {
        let output = try await newSpot().items(timeout: 5)

        XCTAssertEqual(output.search, .script)
        XCTAssertEqual(output.items.map(\.title), ["Copy prompt for AI", "Button", "List", "Live value", "Form"])
        XCTAssertEqual(output.items.dropFirst().map(\.run), SpotStarter.allCases.map(\.rawValue))
        XCTAssertFalse(output.keepsRecent)
        XCTAssertEqual(output.items.first?.subtitle, "Type what the spot should do")
        XCTAssertTrue(Set(output.actions.map(\.id)).isSuperset(of: ["guide", "folder"]))
        XCTAssertEqual(output.primary, "Choose")
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
        XCTAssertEqual(try SpotFolder(url: plugins).scan().spots, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("opened").path))
    }

    func testCopyPromptForAINeedsADescription() async throws {
        do {
            _ = try await newSpot().perform(.item(SpotItem(title: "Copy prompt for AI", run: "ask")), timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "Type what the spot should do, then press `⏎`.")
        }
    }

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

        let first = try await spot.perform(.item(SpotItem(title: "List", run: "list")), timeout: 5)
        let second = try await spot.perform(.item(SpotItem(title: "Button", run: "button")), timeout: 5)

        XCTAssertEqual(first, "Made Untitled. Change the file that opened to make it yours.")
        XCTAssertEqual(second, "Made Untitled 2. Change the file that opened to make it yours.")

        let names = try SpotFolder(url: plugins).scan().spots.map(\.id).sorted()
        XCTAssertEqual(names, ["untitled", "untitled-2"])
        XCTAssertEqual(try saved("opened"), "-t \(plugins.appendingPathComponent("untitled-2.sh").path)\n")
        XCTAssertEqual(try SpotFolder(url: plugins).scan().spots.map(\.name).sorted(), ["Untitled", "Untitled 2"])
    }

    func testTheActionsOpenTheGuideAndTheFolder() async throws {
        let spot = try newSpot()

        _ = try await spot.perform(SpotAction(arguments: ["guide"]), timeout: 5)
        XCTAssertTrue(try saved("opened").contains("GUIDE.md"))

        _ = try await spot.perform(SpotAction(arguments: ["folder"]), timeout: 5)
        XCTAssertTrue(try saved("opened").contains(plugins.path))
    }

    func testAnUnknownCallFails() async throws {
        do {
            _ = try await newSpot().perform(SpotAction(arguments: ["gone"]), timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "New spot cannot do that.")
        }
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

        let faults = await SpotCheck(folder: SpotFolder(url: plugins)).faults()

        XCTAssertEqual(faults, [])
    }

    func testTheGuideIsTheSpecsJoinedInOrder() throws {
        let out = root.appendingPathComponent("built.md")
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = [repo.appendingPathComponent("scripts/guide.sh").path, out.path]
        try script.run()
        script.waitUntilExit()

        XCTAssertEqual(script.terminationStatus, 0)
        XCTAssertTrue(try String(contentsOf: out, encoding: .utf8) == guideText)
        XCTAssertTrue(guideText.hasPrefix("# 01 Core"))
    }

    func testTheGuideTeachesNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "event=", "OPENSPOT_CONFIG", "openspot catalog", "while next", "openspot.input", "function read("] {
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

    /// The specs `00` to `99` of `spec/`, joined in order with one blank line between them.
    private func joinedSpecs() throws -> String {
        let specs = repo.appendingPathComponent("spec")
        let names = try FileManager.default.contentsOfDirectory(atPath: specs.path).filter { $0.first?.isNumber == true && $0.hasSuffix(".md") }.sorted()
        return try names.map { try String(contentsOf: specs.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n")
    }

}
