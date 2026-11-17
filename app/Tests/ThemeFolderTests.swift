import XCTest
@testable import OpenspotCore

final class ThemeFolderTests: XCTestCase {
    private var folder: URL!
    private var themes: ThemeFolder!

    override func setUpWithError() throws {
        folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[shared]\nhover = 0.08\n".write(to: builtIn, atomically: true, encoding: .utf8)
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

        XCTAssertEqual(themes.scan(), ["Openspot", "dusk", "Night"])
        XCTAssertEqual(themes.readInUse(), "Openspot")
        XCTAssertEqual(themes.read().look.dark.fill, 0.1)
    }

    func testUseSwitchesTheThemeAndTheLoadedThemeFollows() throws {
        try write("Night", "[dark]\nfill = 0.3\n")

        XCTAssertEqual(try themes.use("night"), "Night")

        XCTAssertEqual(themes.config.read().theme, "Night")
        XCTAssertEqual(themes.readInUse(), "Night")
        let theme = themes.read()
        XCTAssertEqual(theme.look.dark.fill, 0.3)
        XCTAssertEqual(theme.look.dark.ink, ThemeColor(text: "#FFFFFF"))
        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(try themes.use("Openspot"), "Openspot")
        XCTAssertEqual(themes.read().look.dark.fill, 0.1)
    }

    func testAnUnknownThemeInUseFallsBackToTheBuiltInWithAFault() throws {
        try themes.config.change { $0.set(theme: "Gone") }

        let theme = themes.read()

        XCTAssertEqual(themes.readInUse(), "Openspot")
        XCTAssertEqual(theme.look.dark.fill, 0.1)
        XCTAssertEqual(theme.faults, ["config.toml: the theme Gone is not there, so Openspot uses the theme Openspot. Run `openspot theme list` to see each one."])
    }

    func testNewMakesTheNextFreeNameThatSetsNothingAndShowsEachKeyToChange() throws {
        XCTAssertEqual(try themes.make(), "Theme 2")
        XCTAssertEqual(try themes.make(), "Theme 3")

        XCTAssertEqual(themes.readInUse(), "Theme 3")
        XCTAssertEqual(try text(of: "Theme 2"), "[dark]\n# ink = \"#FFFFFF\"\n# fill = 0.1\n\n[shared]\n# hover = 0.08\n")
        let theme = themes.read()
        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme, ThemeFolder.read(builtIn: themes.builtIn))
    }

    func testDuplicateCopiesTheThemeInUseOrTheNamedOneAndUsesTheCopy() throws {
        XCTAssertEqual(try themes.duplicate(nil), "Openspot copy")
        XCTAssertEqual(try text(of: "Openspot copy"), try String(contentsOf: try XCTUnwrap(themes.builtIn), encoding: .utf8))
        XCTAssertEqual(try themes.duplicate("Openspot"), "Openspot copy 2")
        try write("Night", "[dark]\nfill = 0.3\n")

        XCTAssertEqual(try themes.duplicate("night"), "Night copy")

        XCTAssertEqual(try text(of: "Night copy"), "[dark]\nfill = 0.3\n")
        XCTAssertEqual(themes.readInUse(), "Night copy")
        XCTAssertEqual(themes.read().look.dark.fill, 0.3)
    }

    func testRenameMovesTheFolderAndKeepsItInUse() throws {
        try write("Night", "[dark]\nfill = 0.3\n")
        try themes.use("Night")

        XCTAssertEqual(try themes.rename("Night", to: "Dusk"), "Dusk")

        XCTAssertEqual(themes.scan(), ["Openspot", "Dusk"])
        XCTAssertEqual(themes.readInUse(), "Dusk")
        XCTAssertEqual(themes.read().look.dark.fill, 0.3)
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
        XCTAssertEqual(themes.scan(), ["Openspot"])
        XCTAssertEqual(themes.config.read().theme, "Openspot")
        XCTAssertEqual(themes.read().faults, [])
    }

    func testEditOnTheBuiltInDuplicatesItFirst() throws {
        let file = try themes.edit()

        XCTAssertEqual(file, folder.appendingPathComponent("themes/Openspot copy.theme/theme.toml"))
        XCTAssertEqual(themes.readInUse(), "Openspot copy")
        XCTAssertEqual(try themes.edit(), file)
        XCTAssertEqual(themes.scan(), ["Openspot", "Openspot copy"])
    }

    func testBadNamesAreRefused() throws {
        try write("Night", "")
        try write("Dusk", "")

        XCTAssertEqual(refusal { try themes.use("") }, "A theme needs a name, such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "a/b") }, "A theme's name cannot hold `/`. Pick a name such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "OPENSPOT") }, "Openspot is the name of the built-in theme. Pick another name.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "dusk") }, "A theme named dusk is already there. Pick another name.")
        XCTAssertEqual(refusal { try themes.rename("Openspot", to: "Day") }, "The theme Openspot is built in, so it keeps its name. Run `openspot theme duplicate` to make a copy you can change.")
        XCTAssertEqual(refusal { try themes.delete("Openspot") { $0 } }, "The theme Openspot is built in, so it cannot be deleted.")
        XCTAssertEqual(refusal { try themes.use("Gone") }, "There is no theme named Gone. Run `openspot theme list` to see each one.")
        XCTAssertEqual(refusal { try themes.duplicate("") }, "A theme needs a name, such as `Dusk`.")
        XCTAssertEqual(themes.scan(), ["Openspot", "Dusk", "Night"])
    }

    func testThemesLiveBesideTheConfig() {
        let themes = ThemeFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/openspot-config"], builtIn: nil)

        XCTAssertEqual(themes.url.path, "/tmp/openspot-config/themes")
        XCTAssertEqual(themes.file(of: "Night")?.path, "/tmp/openspot-config/themes/Night.theme/theme.toml")
        XCTAssertNil(themes.file(of: "openspot"))
    }

    func testAWriteChangesOneKeyOfTheThemeAndTheThemeFollows() throws {
        try write("Night", "# Night\n[dark]\n# ink = \"#FFFFFF\"\nfill = 0.3\n")

        try themes.write(ThemeKey(section: "dark", key: "ink"), to: .string("#FF0000"), of: "night")
        try themes.write(ThemeKey(section: "dark", key: "fill"), to: nil, of: "Night")

        XCTAssertEqual(try text(of: "Night"), "# Night\n[dark]\nink = \"#FF0000\"\n# fill = 0.3\n")
        try themes.use("Night")
        XCTAssertEqual(themes.read().look.dark.ink, ThemeColor(text: "#FF0000"))
        XCTAssertEqual(themes.read().look.dark.fill, 0.1)
    }

    func testTheBuiltInThemeRefusesAWrite() {
        XCTAssertEqual(
            refusal { try themes.write(ThemeKey(section: "dark", key: "fill"), to: .number(0.5), of: "Openspot") },
            "The theme Openspot is built in, so it can't change. Run `openspot theme duplicate` to make a copy you can change."
        )
        XCTAssertEqual(refusal { try themes.write(ThemeKey(section: "dark", key: "fill"), to: .number(0.5), of: "Gone") }, "There is no theme named Gone. Run `openspot theme list` to see each one.")
    }

    func testTheRowsHoldEachKeyWithItsValueAndWhetherTheThemeSetsIt() throws {
        try write("Night", "[dark]\nfill = 0.3\n# ink = \"#000000\"\n")

        let rows = try themes.readRows(of: "Night")
        let builtIn = try themes.readRows(of: "Openspot")

        XCTAssertEqual(rows, [
            ThemeRow(group: "look", id: ThemeKey(section: "dark", key: "ink"), kind: .colour, cells: [
                ThemeRow.Cell(key: ThemeKey(section: "dark", key: "ink"), value: .string("#FFFFFF"), isSet: false)
            ]),
            ThemeRow(group: "look", id: ThemeKey(section: "dark", key: "fill"), kind: .strength, cells: [
                ThemeRow.Cell(key: ThemeKey(section: "dark", key: "fill"), value: .number(0.3), isSet: true)
            ]),
            ThemeRow(group: "shared", id: ThemeKey(section: "shared", key: "hover"), kind: .strength, cells: [
                ThemeRow.Cell(key: ThemeKey(section: "shared", key: "hover"), value: .number(0.08), isSet: false)
            ])
        ])
        XCTAssertEqual(builtIn.flatMap(\.cells).map(\.isSet), [false, false, false])
    }

    func testANameLosesItsOuterSpacesAndCannotStartWithADotOrHoldANewLine() throws {
        try write("Night", "")

        XCTAssertEqual(refusal { try themes.rename("Night", to: ".hidden") }, "A theme's name cannot start with `.`. Pick a name such as `Dusk`.")
        XCTAssertEqual(refusal { try themes.rename("Night", to: "a\nb") }, "A theme's name cannot hold a new line. Pick a name such as `Dusk`.")
        XCTAssertEqual(try themes.rename("Night", to: " Dusk "), "Dusk")
        XCTAssertEqual(themes.scan(), ["Openspot", "Dusk"])
    }

    func testARenameThatChangesOnlyTheCaseKeepsTheTheme() throws {
        try write("Dusk", "[dark]\nfill = 0.3\n")
        try themes.use("Dusk")

        XCTAssertEqual(try themes.rename("Dusk", to: "dusk"), "dusk")

        XCTAssertEqual(themes.scan(), ["Openspot", "dusk"])
        XCTAssertEqual(themes.readInUse(), "dusk")
        XCTAssertEqual(themes.read().look.dark.fill, 0.3)
    }
}
