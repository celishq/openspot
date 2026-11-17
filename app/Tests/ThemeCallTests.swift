import XCTest
@testable import OpenspotCore

final class ThemeCallTests: XCTestCase {
    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

    private func api(_ config: URL, app: FakeRunningApp, theme: URL? = nil) -> CommandAPI {
        let trash = config.appendingPathComponent("Trash")
        let places = AppPlaces(environment: ["OPENSPOT_CONFIG": config.path], home: config, defaults: UserDefaults(suiteName: "openspot-test-\(UUID().uuidString)") ?? .standard, trash: { url in
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            let place = trash.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: place)
            return place
        }, defaultConfig: nil)
        return CommandAPI(mac: Mac(theme: theme ?? builtInURL), places: places, app: app, rates: .offline)
    }

    private func answer(_ api: CommandAPI, _ arguments: [String]) async throws -> CommandAnswer {
        try await XCTUnwrap(api.work(for: .test(arguments), input: { "" }))()
    }

    func testEachVerbAnswersAndTheAppDrawsWithTheThemeInUse() async throws {
        let config = try temporaryFolder()
        let app = FakeRunningApp()
        let api = api(config, app: app)

        let made = try await answer(api, ["theme", "new"])
        let copied = try await answer(api, ["theme", "duplicate", "Openspot"])
        let renamed = try await answer(api, ["theme", "rename", "Openspot copy", "Dusk"])
        let used = try await answer(api, ["theme", "use", "Theme 2"])
        let list = try await answer(api, ["theme", "list", "--frame"])
        let json = try await answer(api, ["theme", "list"])
        let deleted = try await answer(api, ["theme", "delete", "Theme 2"])

        XCTAssertEqual(made.output, "Made the theme Theme 2, and switched to it.\n")
        XCTAssertEqual(copied.output, "Made the theme Openspot copy, and switched to it.\n")
        XCTAssertEqual(renamed.output, "Renamed the theme Openspot copy to Dusk.\n")
        XCTAssertEqual(used.output, "Switched to the theme Theme 2.\n")
        XCTAssertEqual(list.output, "theme=Openspot\nbuiltin=true\n\ntheme=Dusk\n\ntheme=Theme 2\nused=true\n\n")
        XCTAssertEqual(json.output, #"[{"builtin":true,"theme":"Openspot","used":false},{"builtin":false,"theme":"Dusk","used":false},{"builtin":false,"theme":"Theme 2","used":true}]"# + "\n")
        XCTAssertEqual(deleted.output, "Moved the theme Theme 2 to the Trash, and switched to the theme Openspot.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: config.appendingPathComponent("Trash").path), ["Theme 2.theme"])
        let themes = await app.themes
        XCTAssertEqual(themes.count, 4)
        XCTAssertEqual(themes.map(\.faults), [[], [], [], []])
    }

    func testAReloadDrawsWithTheFileOfTheThemeInUse() async throws {
        let config = try temporaryFolder()
        let app = FakeRunningApp()
        let api = api(config, app: app)
        _ = try await answer(api, ["theme", "new"])
        try "[glass]\nbackdrop-blur = 8\n".write(to: config.appendingPathComponent("themes/Theme 2.theme/theme.toml"), atomically: true, encoding: .utf8)

        let reloaded = try await answer(api, ["theme", "reload"])

        XCTAssertEqual(reloaded, CommandAnswer())
        let themes = await app.themes
        XCTAssertEqual(themes.last?.look.glass.backdropBlur, 8)
        XCTAssertEqual(themes.last?.look.glass.variant, .clear)
    }

    func testTheListMarksEachBuiltInThemeAndPutsThemFirst() async throws {
        let config = try temporaryFolder()
        let shipped = config.appendingPathComponent("Openspot.app/Themes")
        let openspot = shipped.appendingPathComponent("openspot.theme/theme.toml")
        try FileManager.default.createDirectory(at: openspot.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: builtInURL, to: openspot)
        try FileManager.default.createDirectory(at: shipped.appendingPathComponent("paper.theme"), withIntermediateDirectories: true)
        try "[shared]\naccent = \"#FF9F0A\"\n".write(to: shipped.appendingPathComponent("paper.theme/theme.toml"), atomically: true, encoding: .utf8)
        let app = FakeRunningApp()
        let api = api(config, app: app, theme: openspot)
        _ = try await answer(api, ["theme", "new"])

        let list = try await answer(api, ["theme", "list", "--frame"])
        let used = try await answer(api, ["theme", "use", "paper"])

        XCTAssertEqual(list.output, "theme=Openspot\nbuiltin=true\n\ntheme=Paper\nbuiltin=true\n\ntheme=Theme 2\nused=true\n\n")
        XCTAssertEqual(used.output, "Switched to the theme Paper.\n")
        let themes = await app.themes
        XCTAssertEqual(themes.last?.look.shared.accent, ThemeColor(text: "#FF9F0A"))
    }

    func testABadNameIsAFailureLine() async throws {
        let api = api(try temporaryFolder(), app: FakeRunningApp())

        let refused = try await answer(api, ["theme", "rename", "Openspot", "Day"])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "The theme Openspot is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.\n")
    }

    func testEachVerbIsOneOfTheThemeNoun() {
        let parse = { (words: [String]) in CommandLineCall(arguments: ["theme"] + words, environment: [:])?.value as? ThemeCall }

        XCTAssertEqual(parse(["reload"]), .reload)
        XCTAssertEqual(parse(["open"]), .open(nil))
        XCTAssertEqual(parse(["open", "Dusk"]), .open("Dusk"))
        XCTAssertNil(parse(["edit"]))
        XCTAssertEqual(parse(["list"]), .list(.json))
        XCTAssertEqual(parse(["use", "Dusk"]), .use("Dusk"))
        XCTAssertEqual(parse(["new"]), .new)
        XCTAssertEqual(parse(["duplicate"]), .duplicate(nil))
        XCTAssertEqual(parse(["duplicate", "Dusk"]), .duplicate("Dusk"))
        XCTAssertEqual(parse(["rename", "Dusk", "Night"]), .rename("Dusk", "Night"))
        XCTAssertEqual(parse(["delete", "Dusk"]), .delete("Dusk"))
        XCTAssertNil(parse(["rename", "Dusk"]))
        XCTAssertNil(CommandLineCall(arguments: ["app", "theme"], environment: [:])?.value as? AppCall)
    }
}
