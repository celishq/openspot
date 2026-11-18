import XCTest
@testable import OpenspotCore

final class ThemeFolderTests: XCTestCase {
    private var folder: URL!
    private var themes: ThemeFolder!

    override func setUpWithError() throws {
        folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[look]\ncorner = 20\n".write(to: builtIn, atomically: true, encoding: .utf8)
        themes = ThemeFolder(url: folder.appendingPathComponent("themes"), builtIn: builtIn, config: ConfigFile(url: folder.appendingPathComponent("config.toml")))
    }

    private func write(_ name: String, _ text: String) throws {
        let file = folder.appendingPathComponent("themes/\(name).theme/theme.toml")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func text(of name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent("themes/\(name).theme/theme.toml"), encoding: .utf8)
    }

    private func refusal(_ work: () throws -> Any) -> String? {
        do {
            _ = try work()
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    func testTheListHoldsTheBuiltInThenEachFolderButOneNamedLikeTheBuiltIn() throws {
        try write("Night", "[dark]\nfill = 0.3\n")
        try write("dusk", "")
        try write("openspot", "[dark]\nfill = 0.9\n")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("themes/Empty.theme"), withIntermediateDirectories: true)

        XCTAssertEqual(themes.scan().names, ["Openspot", "dusk", "Night"])
        XCTAssertEqual(themes.readInUse(), "Openspot")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.1)
    }

    func testAFolderNamedLikeABuiltInIsNotAThemeAndIsAFaultThatSaysToRenameIt() throws {
        try write("openspot", "[dark]\nfill = 0.9\n")
        try write("Night", "")

        XCTAssertEqual(themes.scan().names, ["Openspot", "Night"])
        XCTAssertEqual(refusal { try themes.use("openspot") }, nil)
        XCTAssertEqual(themes.read().colours.dark.fill, 0.1)
        XCTAssertEqual(themes.read().faults, ["The folder \(folder.appendingPathComponent("themes/openspot.theme").path) has the name of the built-in theme Openspot, so Openspot skips it. Rename the folder."])
    }

    func testUseRefusesAThemeWithFaultsAndKeepsTheOneInUse() throws {
        try write("Night", "")
        try write("Bad", "[dark]\nfill = 5\n")
        try themes.use("Night")

        XCTAssertEqual(refusal { try themes.use("bad") }, "The theme Bad has faults, so Openspot keeps the theme Night. Fix each line below, then run `openspot theme use Bad` again.\ntheme.toml: [dark] fill is a strength from 0 to 1, such as 0.2.")
        XCTAssertEqual(themes.config.read().theme, "Night")
    }

    func testUseSwitchesTheThemeAndTheLoadedThemeFollows() throws {
        try write("Night", "[dark]\nfill = 0.3\n")

        XCTAssertEqual(try themes.use("night"), "Night")

        XCTAssertEqual(themes.config.read().theme, "Night")
        XCTAssertEqual(themes.readInUse(), "Night")
        let theme = themes.read()
        XCTAssertEqual(theme.colours.dark.fill, 0.3)
        XCTAssertEqual(theme.colours.dark.ink, ThemeColor(text: "#FFFFFF"))
        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(try themes.use("Openspot"), "Openspot")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.1)
    }

    func testAnUnknownThemeInUseFallsBackToTheBuiltInWithAFault() throws {
        try themes.config.change { $0.set(theme: "Gone") }

        let theme = themes.read()

        XCTAssertEqual(themes.readInUse(), "Openspot")
        XCTAssertEqual(theme.colours.dark.fill, 0.1)
        XCTAssertEqual(theme.faults, ["config.toml: the theme Gone is not there, so Openspot uses the theme Openspot. Run `openspot theme list` to see each one."])
    }

    func testNewMakesTheNextFreeNameThatSetsNothingAndShowsEachKeyToChange() throws {
        XCTAssertEqual(try themes.make(), "Theme 2")
        XCTAssertEqual(try themes.make(), "Theme 3")

        XCTAssertEqual(themes.readInUse(), "Theme 3")
        XCTAssertEqual(try text(of: "Theme 2"), "[dark]\n# ink = \"#FFFFFF\"\n# fill = 0.1\n\n[look]\n# corner = 20\n")
        let theme = themes.read()
        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.colours, ThemeFolder.read(builtIn: themes.builtIn).colours)
        XCTAssertEqual(theme.layout, ThemeFolder.read(builtIn: themes.builtIn).layout)
    }

    func testDuplicateCopiesTheThemeInUseOrTheNamedOneAndUsesTheCopy() throws {
        XCTAssertEqual(try themes.duplicate(nil), "Openspot copy")
        XCTAssertEqual(try text(of: "Openspot copy"), try String(contentsOf: try XCTUnwrap(themes.builtIn), encoding: .utf8))
        XCTAssertEqual(try themes.duplicate("Openspot"), "Openspot copy 2")
        try write("Night", "[dark]\nfill = 0.3\n")

        XCTAssertEqual(try themes.duplicate("night"), "Night copy")

        XCTAssertEqual(try text(of: "Night copy"), "[dark]\nfill = 0.3\n")
        XCTAssertEqual(themes.readInUse(), "Night copy")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.3)
    }

    func testRenameMovesTheFolderAndKeepsItInUse() throws {
        try write("Night", "[dark]\nfill = 0.3\n")
        try themes.use("Night")

        XCTAssertEqual(try themes.rename("Night", to: "Dusk"), "Dusk")

        XCTAssertEqual(themes.scan().names, ["Openspot", "Dusk"])
        XCTAssertEqual(themes.readInUse(), "Dusk")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.3)
    }

    func testDeleteMovesTheFolderToTheTrashAndFallsBackWhenItWasInUse() throws {
        try write("Night", "[dark]\nfill = 0.3\n")
        try write("Dusk", "")
        try themes.use("Night")
        var trashed: [String] = []

        XCTAssertEqual(try themes.delete("Dusk") { trashed.append($0.lastPathComponent); try FileManager.default.removeItem(at: $0); return $0 }, false)
        XCTAssertEqual(themes.readInUse(), "Night")
        XCTAssertEqual(try themes.delete("Night") { trashed.append($0.lastPathComponent); try FileManager.default.removeItem(at: $0); return $0 }, true)

        XCTAssertEqual(trashed, ["Dusk.theme", "Night.theme"])
        XCTAssertEqual(themes.scan().names, ["Openspot"])
        XCTAssertEqual(themes.config.read().theme, "Openspot")
        XCTAssertEqual(themes.read().faults, [])
    }

    func testEditOnTheBuiltInDuplicatesItFirst() throws {
        let file = try themes.edit().file

        XCTAssertEqual(file, folder.appendingPathComponent("themes/Openspot copy.theme/theme.toml"))
        XCTAssertEqual(themes.readInUse(), "Openspot copy")
        XCTAssertEqual(try themes.edit().file, file)
        XCTAssertEqual(themes.scan().names, ["Openspot", "Openspot copy"])
    }

    func testBadNamesAreRefused() throws {
        try write("Night", "")
        try write("Dusk", "")

        XCTAssertEqual(refusal { try themes.use("") }, "A theme needs a name, such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "a/b") }, "A theme's name cannot hold `/`. Pick a name such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "OPENSPOT") }, "Openspot is the name of a built-in theme. Pick another name.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "dusk") }, "A theme named dusk is already there. Pick another name.")
        XCTAssertEqual(refusal { try themes.rename("Openspot", to: "Day") }, "The theme Openspot is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        XCTAssertEqual(refusal { try themes.delete("Openspot") { $0 } }, "The theme Openspot is built in, so it cannot be deleted.")
        XCTAssertEqual(refusal { try themes.use("Gone") }, "There is no theme named Gone. Run `openspot theme list` to see each one.")
        XCTAssertEqual(refusal { try themes.duplicate("") }, "A theme needs a name, such as `Dusk`.")
        XCTAssertEqual(themes.scan().names, ["Openspot", "Dusk", "Night"])
    }

    func testEachFolderBesideTheBuiltInIsABuiltInThemeListedFirstThatOnlyACopyChanges() throws {
        let shipped = folder.appendingPathComponent("Openspot.app/Themes")
        let openspot = shipped.appendingPathComponent("openspot.theme/theme.toml")
        let dusk = shipped.appendingPathComponent("dusk.theme/theme.toml")
        for (file, text) in [(openspot, "[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[look]\ncorner = 20\n"), (dusk, "[dark]\nfill = 0.4\n")] {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        let themes = ThemeFolder(url: folder.appendingPathComponent("themes"), builtIn: openspot, config: ConfigFile(url: folder.appendingPathComponent("config.toml")))
        try write("Night", "")
        try write("dusk", "[dark]\nfill = 0.9\n")

        XCTAssertEqual(themes.scan().names, ["Openspot", "Dusk", "Night"])
        XCTAssertEqual(try themes.use("dusk"), "Dusk")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.4)
        XCTAssertEqual(themes.read().layout.radius.card, 20)
        XCTAssertEqual(themes.read().faults, ["The folder \(folder.appendingPathComponent("themes/dusk.theme").path) has the name of the built-in theme Dusk, so Openspot skips it. Rename the folder."])

        XCTAssertEqual(try themes.duplicate("Dusk"), "Dusk copy")
        XCTAssertEqual(try text(of: "Dusk copy"), "[dark]\nfill = 0.4\n")
        XCTAssertEqual(themes.scan().names, ["Openspot", "Dusk", "Dusk copy", "Night"])
        XCTAssertEqual(refusal { try themes.rename("Dusk", to: "Day") }, "The theme Dusk is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        XCTAssertEqual(refusal { try themes.delete("Dusk") { $0 } }, "The theme Dusk is built in, so it cannot be deleted.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "DUSK") }, "Dusk is the name of a built-in theme. Pick another name.")
        XCTAssertEqual(try String(contentsOf: dusk, encoding: .utf8), "[dark]\nfill = 0.4\n")
    }

    func testThemesLiveBesideTheConfig() {
        let themes = ThemeFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/openspot-config"], builtIn: nil)

        XCTAssertEqual(themes.url.path, "/tmp/openspot-config/themes")
        XCTAssertEqual(themes.file(of: "Night").path, "/tmp/openspot-config/themes/Night.theme/theme.toml")
    }

    func testANameLosesItsOuterSpacesAndCannotStartWithADotOrHoldANewLine() throws {
        try write("Night", "")

        XCTAssertEqual(refusal { try themes.rename("Night", to: ".hidden") }, "A theme's name cannot start with `.`. Pick a name such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "a\nb") }, "A theme's name cannot hold a new line. Pick a name such as `Dusk`.")
        XCTAssertEqual(try themes.rename("Night", to: " Dusk "), "Dusk")
        XCTAssertEqual(themes.scan().names, ["Openspot", "Dusk"])
    }

    func testARenameThatChangesOnlyTheCaseKeepsTheTheme() throws {
        try write("Dusk", "[dark]\nfill = 0.3\n")
        try themes.use("Dusk")

        XCTAssertEqual(try themes.rename("Dusk", to: "dusk"), "dusk")

        XCTAssertEqual(themes.scan().names, ["Openspot", "dusk"])
        XCTAssertEqual(themes.readInUse(), "dusk")
        XCTAssertEqual(themes.read().colours.dark.fill, 0.3)
    }
}
