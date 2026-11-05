import XCTest
@testable import OpenspotCore

final class GuidePluginTests: XCTestCase {
    private var folder: URL!
    private var plugins: URL!
    private var guideText = ""
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-guide-\(UUID().uuidString)")
        plugins = folder.appendingPathComponent("plugins")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: root.appendingPathComponent("plugins/guide"), to: plugins.appendingPathComponent("guide"))
        guideText = try String(contentsOf: plugins.appendingPathComponent("guide/GUIDE.md"), encoding: .utf8)
        for (name, script) in [("pbcopy", "cat > '\(folder.path)/clipboard'"), ("open", "echo \"$1\" > '\(folder.path)/opened'")] {
            let tool = tools.appendingPathComponent(name)
            try "#!/bin/sh\n\(script)\n".write(to: tool, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
    }

    override func tearDownWithError() throws {
        if let path { setenv("PATH", path, 1) }
        try FileManager.default.removeItem(at: folder)
    }

    private func guide() throws -> PluginCommand {
        try XCTUnwrap(try PluginFolder(url: plugins).scan().commands.first { $0.id == "guide/Plugins" })
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testThePromptNamesTheGuideTheFolderAndTheCheck() async throws {
        try await guide().perform(.item(SpotItem(title: "Copy", run: "prompt")), timeout: 5)

        let prompt = try saved("clipboard")

        XCTAssertTrue(prompt.contains("GUIDE.md"))
        XCTAssertTrue(prompt.contains(plugins.path))
        XCTAssertTrue(prompt.contains("--check"))
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
        let action = try XCTUnwrap(guide.actions.first { $0.id == "new" })
        let form = try await guide.form(action, item: nil, timeout: 5)
        var draft = FormDraft(form: form)
        draft.set("My Weather", for: "name")

        _ = try await guide.submit(action, item: nil, draft: draft, timeout: 5)

        let scan = try PluginFolder(url: plugins).scan()
        let made = scan.commands.first { $0.id == "my-weather/My Weather" }
        XCTAssertEqual(scan.refused, [])
        XCTAssertNotNil(made)
        try await XCTUnwrap(made).perform(.run, timeout: 5)
        XCTAssertTrue(try saved("opened").contains("my-weather"))
    }

    func testNewPluginKeepsAPluginThatExists() async throws {
        let guide = try guide()
        let action = try XCTUnwrap(guide.actions.first { $0.id == "new" })
        var draft = FormDraft(form: try await guide.form(action, item: nil, timeout: 5))
        draft.set("Guide", for: "name")

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

    func testEachExamplePluginInTheGuideLoadsAndAnswers() async throws {
        let examples = blocks("toml").filter { $0.contains("api = 1") && !$0.contains("[[widgets]]\nname = \"Morning\"") }
        let scripts = blocks("sh")
        XCTAssertEqual(examples.count, scripts.count)
        for (manifest, script) in zip(examples, scripts) {
            let name = try XCTUnwrap(try TomlDocument(text: manifest).values["name"])
            guard case .string(let title) = name else { return XCTFail("no name") }
            let directory = plugins.appendingPathComponent(title.lowercased())
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try manifest.write(to: directory.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
            for exec in Self.execs(in: manifest) {
                let url = directory.appendingPathComponent(exec)
                try script.write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }

        let faults = await PluginCheck(folder: PluginFolder(url: plugins)).faults()

        XCTAssertEqual(faults, [])
    }

    private static func execs(in manifest: String) -> [String] {
        manifest.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("exec = ") else { return nil }
            return line.dropFirst(7).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }
}
