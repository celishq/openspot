import XCTest
@testable import OpenspotCore

final class BuildSpotTests: XCTestCase {
    private var folder: URL!
    private var plugins: URL!
    private var guideText = ""
    private var guideURL: URL!
    private var root: URL!
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-guide-\(UUID().uuidString)")
        plugins = folder.appendingPathComponent("plugins")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        guideURL = folder.appendingPathComponent("GUIDE.md")
        guideText = try joinedSpecs()
        try guideText.write(to: guideURL, atomically: true, encoding: .utf8)
        for (name, script) in [("pbcopy", "cat > '\(folder.path)/clipboard'"), ("open", "echo \"$1\" > '\(folder.path)/opened'")] {
            let tool = tools.appendingPathComponent(name)
            try "#!/bin/sh\n\(script)\n".writeScript(to: tool)
        }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
    }

    override func tearDownWithError() throws {
        if let path { setenv("PATH", path, 1) }
        try FileManager.default.removeItem(at: folder)
    }

    private func newAction(of guide: Spot) async throws -> CommandAction {
        let actions = try await guide.items(timeout: 5).actions
        return try XCTUnwrap(actions.first { $0.id == "new" })
    }

    private func guide() throws -> Spot {
        try XCTUnwrap(ShippedSpot.commands(folder: plugins, guide: guideURL, app: "/Apps/Openspot").first { $0.name == "Build" })
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheSpotsSpotShowsWithAnEmptyFolderAndKeepsItsKey() throws {
        try "#!/bin/sh\n# shortcut=p\n".writeScript(to: plugins.appendingPathComponent("mine.sh"))
        let shipped = ShippedSpot.commands(folder: plugins, guide: guideURL, app: "")

        let scan = try PluginFolder(url: plugins).scan(shipped: shipped)

        XCTAssertEqual(scan.commands.first { $0.key?.name == "p" }?.name, "Spots")
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "mine", reason: "Mine cannot use key p, because another command has it")])
    }

    func testTheBuildSpotListsItsRowsAndItsAction() async throws {
        let guide = try guide()

        let lines = try await guide.items(timeout: 5)

        XCTAssertEqual(guide.kind, .list)
        XCTAssertEqual(lines.actions.map(\.id), ["new"])
        XCTAssertFalse(lines.keepsRecent)
        XCTAssertEqual(lines.items.map(\.run), ["prompt", "sandbox", "guide", "folder"])
        XCTAssertEqual(lines.errors, [])
    }

    func testThePromptNamesTheGuideTheFolderAndTheCheck() async throws {
        try await guide().perform(.item(SpotItem(title: "Copy", run: "prompt")), timeout: 5)

        let prompt = try saved("clipboard")

        XCTAssertTrue(prompt.contains("GUIDE.md"))
        XCTAssertTrue(prompt.contains(plugins.path))
        XCTAssertTrue(prompt.contains("check"))
    }

    func testThePromptSaysItIsCopied() async throws {
        let toast = try await guide().perform(.item(SpotItem(title: "Copy", run: "prompt")), timeout: 5)

        XCTAssertEqual(toast, "Copied")
    }

    func testTheRowsOpenTheGuideAndTheFolder() async throws {
        let guide = try guide()

        try await guide.perform(.item(SpotItem(title: "Guide", run: "guide")), timeout: 5)
        XCTAssertTrue(try saved("opened").contains("GUIDE.md"))

        try await guide.perform(.item(SpotItem(title: "Folder", run: "folder")), timeout: 5)
        XCTAssertTrue(try saved("opened").contains(plugins.path))
    }

    func testNewPluginMakesAWorkingPlugin() async throws {
        let guide = try guide()
        let action = try await newAction(of: guide)
        let form = try await guide.form(action, item: nil, timeout: 5)
        var draft = FormDraft(form: form)
        draft.set("My Weather", for: "name")

        _ = try await guide.submit(action, item: nil, draft: draft, timeout: 5)

        let scan = try PluginFolder(url: plugins).scan()
        let made = scan.commands.first { $0.id == "my-weather" }
        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(made?.name, "My Weather")
        try await XCTUnwrap(made).perform(XCTUnwrap(made).click, timeout: 5)
        XCTAssertEqual(try saved("opened"), "-R\n")
    }

    func testNewPluginKeepsAPluginThatExists() async throws {
        let guide = try guide()
        let action = try await newAction(of: guide)
        var draft = FormDraft(form: try await guide.form(action, item: nil, timeout: 5))
        draft.set("Guide", for: "name")
        try FileManager.default.createDirectory(at: plugins.appendingPathComponent("guide"), withIntermediateDirectories: true)

        do {
            _ = try await guide.submit(action, item: nil, draft: draft, timeout: 5)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual(error as? PluginError, .failed(1, "A plugin called guide already exists."))
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

    func testTheGuideAndTheCatalogTeachNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "event=", "OPENSPOT_CONFIG"] {
            XCTAssertFalse(guideText.contains(old), old)
            XCTAssertFalse(PartCatalog.text.contains(old), old)
        }
    }

    func testTheWidgetExampleInTheReadmeLoads() throws {
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let example = try XCTUnwrap(readme.components(separatedBy: "```toml\n").dropFirst().first?.components(separatedBy: "```").first)
        let widgets = try XCTUnwrap(try TomlDocument(text: example).arrays["widgets"])
        guard case .strings(let grid)? = widgets.first?["grid"], case .table(let places)? = widgets.first?["places"] else {
            return XCTFail("no grid or places")
        }

        XCTAssertEqual(WidgetLayout(drawing: grid).letters.sorted(), places.keys.sorted())
    }

    /// The specs `00` to `99` of `spec/`, joined in order with one blank line between them.
    private func joinedSpecs() throws -> String {
        let specs = root.appendingPathComponent("spec")
        let names = try FileManager.default.contentsOfDirectory(atPath: specs.path).filter { $0.first?.isNumber == true && $0.hasSuffix(".md") }.sorted()
        return try names.map { try String(contentsOf: specs.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n")
    }

}
