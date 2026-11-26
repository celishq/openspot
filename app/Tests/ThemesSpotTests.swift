import XCTest
@testable import OpenspotCore

final class ThemesSpotTests: BuiltInCase {
    private var effects: (() -> [String])!

    override func setUp() async throws {
        try await super.setUp()
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "[ \"$1 $2\" = 'clipboard copy' ] && exec cat > '\(root.path)/clipboard'\nexec '\(real.path)' \"$@\"")
        effects = try recordEffects()
    }

    private var themes: Spot {
        get throws {
            try spot("themes")
        }
    }

    private func theme(_ name: String, _ text: String) throws {
        let file = root.appendingPathComponent("themes/\(name).theme/theme.toml")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    func testTheListShowsTheBuiltInThemeFirstWithTheOneInUseCheckedAndOnlyTheActsThatCanRun() async throws {
        try theme("Night", "[dark]\nfill = 0.3\n")
        try file.change { $0.set(theme: "Night") }

        let output = try await themes.items(timeout: 60)

        XCTAssertEqual(output.items.first?.run, "Openspot")
        XCTAssertEqual(output.items.last?.run, "Night")
        XCTAssertEqual(output.items.filter(\.isOn).map(\.run), ["Night"])
        XCTAssertEqual(Set(output.items.dropLast().map(\.subtitle)), ["Built in"])
        XCTAssertEqual(Set(output.items.dropLast().map { $0.hides ?? [] }), [["rename", "delete", "file"]])
        XCTAssertEqual(output.items.last?.hides ?? [], [])
        XCTAssertEqual(output.actions.map(\.title), ["Duplicate", "Rename", "Move to Trash", "Open file", "Copy prompt"])
    }

    func testItStaysOffTheGridUntilThePersonAddsIt() throws {
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(defaults.arrangement.isOnGrid(of: try themes.id), false)
    }

    func testReturnUsesATheme() async throws {
        try theme("Night", "")

        let output = try await themes.answer("press", input: "input.item=Night\n", timeout: 60)

        XCTAssertEqual(file.read().theme, "Night")
        XCTAssertEqual(output.items.filter(\.isOn).map(\.run), ["Night"])
        let drawn = await app.themes
        XCTAssertEqual(drawn.count, 1)
    }

    func testDuplicateRenameAndMoveToTrashChangeTheThemes() async throws {
        try await themes.perform("duplicate", input: "input.item=Openspot\n", timeout: 60)
        let form = try await themes.answer("rename", input: "input.item=Openspot copy\n", timeout: 60)
        let renamed = try await themes.answer("rename", input: "input.item=Openspot copy\ninput.name= Dusk \n", timeout: 60)
        try await themes.perform("delete", input: "input.item=Dusk\n", timeout: 60)

        XCTAssertEqual(form.fields.map { $0.block.value("field") }, ["name"])
        XCTAssertEqual(renamed.items.filter { $0.subtitle != "Built in" }.map(\.run), ["Dusk"])
        XCTAssertEqual(effects().dropFirst(), ["select Dusk", "toast Moved the theme Dusk to the Trash, and switched to the theme Openspot."])
        XCTAssertEqual(file.read().theme, "Openspot")
    }

    func testCopyPromptPushesAPageWhoseButtonCopiesAPromptThatChangesACopyOfTheBuiltInTheme() async throws {
        _ = try await themes.answer("prompt", input: "input.item=Openspot\n", timeout: 60)
        let page = try await themes.items(page: "prompt:Openspot", timeout: 60)
        try await themes.perform("copy", input: "input.describe=Warm and round\n", page: "prompt:Openspot", timeout: 60)

        XCTAssertEqual(page.fields.map { $0.block.value("field") }, ["describe"])
        XCTAssertEqual(effects(), ["route push prompt:Openspot --title Openspot", "toast \(SpotPrompt.copied)"])
        let prompt = try String(contentsOf: root.appendingPathComponent("clipboard"), encoding: .utf8)
        XCTAssertTrue(prompt.hasSuffix("<request>\nWarm and round\n</request>"), prompt)
        XCTAssertTrue(prompt.contains(ThemePrompt.finish), prompt)
        XCTAssertFalse(prompt.contains("Ask me"), prompt)
        XCTAssertTrue(prompt.contains("theme duplicate 'Openspot'"), prompt)
        XCTAssertTrue(prompt.contains(root.appendingPathComponent("themes").path), prompt)
        XCTAssertTrue(prompt.contains("guide use-openspot"), prompt)
        XCTAssertTrue(prompt.contains("[look] "), prompt)
        XCTAssertTrue(prompt.contains("theme reload"), prompt)
    }

    func testThePromptOfAnOwnThemeNamesItsFile() async throws {
        try theme("Night", "")

        try await themes.perform("copy", input: "input.describe=Darker\n", page: "prompt:Night", timeout: 60)

        let prompt = try String(contentsOf: root.appendingPathComponent("clipboard"), encoding: .utf8)
        XCTAssertTrue(prompt.contains("theme use 'Night'. Then change the file \(root.appendingPathComponent("themes/Night.theme/theme.toml").path)."), prompt)
        XCTAssertFalse(prompt.contains("duplicate"), prompt)
    }
}
