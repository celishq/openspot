import XCTest
@testable import OpenspotCore

final class GuidePluginTests: XCTestCase {
    private var folder: URL!
    private var plugins: URL!
    private var guideText = ""
    private var guideURL: URL!
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-guide-\(UUID().uuidString)")
        plugins = folder.appendingPathComponent("plugins")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        guideURL = root.appendingPathComponent("app/Shell/GUIDE.md")
        guideText = try String(contentsOf: guideURL, encoding: .utf8)
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

    private func newAction(of guide: PluginCommand) async throws -> CommandAction {
        let actions = try await guide.items(timeout: 5).actions
        return try XCTUnwrap(actions.first { $0.id == "new" })
    }

    private func guide() throws -> PluginCommand {
        try XCTUnwrap(ShippedSpot.commands(folder: plugins, guide: guideURL, app: "/Apps/Openspot").first { $0.name == "Build" })
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testTheSpotsSpotShowsWithAnEmptyFolderAndKeepsItsKey() throws {
        try "#!/bin/sh\n# key=p\n".writeScript(to: plugins.appendingPathComponent("mine.sh"))
        let shipped = ShippedSpot.commands(folder: plugins, guide: guideURL, app: "")

        let scan = try PluginFolder(url: plugins).scan(shipped: shipped)

        XCTAssertEqual(scan.commands.first { $0.key?.name == "p" }?.name, "Spots")
        XCTAssertEqual(scan.refused, [Refusal(file: "mine", reason: "Mine cannot use key p, because another command has it")])
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
        XCTAssertEqual(try String(contentsOf: plugins.appendingPathComponent("my-weather.sh"), encoding: .utf8).split(separator: "\n")[1], "# name=My Weather")
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

    func testTheGuideAndTheCatalogTeachNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "event=", "OPENSPOT_CONFIG"] {
            XCTAssertFalse(guideText.contains(old), old)
            XCTAssertFalse(PartCatalog.text.contains(old), old)
        }
    }

    func testTheWidgetExampleInTheGuideLoads() throws {
        let example = try XCTUnwrap(blocks("toml").first)
        let widgets = try XCTUnwrap(try TomlDocument(text: example).arrays["widgets"])
        guard case .string(let layout)? = widgets.first?["layout"], case .strings(let places)? = widgets.first?["places"] else {
            return XCTFail("no layout or places")
        }

        XCTAssertEqual(WidgetLayout(name: layout)?.slots.count, places.count)
    }
}
