import XCTest
@testable import OpenspotCore

final class ThemeTests: XCTestCase {
    func testAThemeGivesEachAppearanceItsGlassTint() {
        let theme = Theme(text: "dark.glass-tint = \"#00000099\"\nlight.glass-tint = \"#FFFFFF\"\n")

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.dark.glassTint, HexColor(text: "#00000099"))
        XCTAssertEqual(theme.dark.glassTint.alpha, 0.6, accuracy: 0.001)
        XCTAssertEqual(theme.light.glassTint.red, 1)
        XCTAssertEqual(theme.light.glassTint.alpha, 1)
    }

    func testAThemeNamesEachValueItCannotRead() {
        let theme = Theme(text: "dark.glass-tint = \"black\"\ndark.ink = \"#FFFFFF\"\n")

        XCTAssertEqual(theme.faults, [
            "theme.toml: dark.glass-tint is a colour such as #00000099.",
            "theme.toml: dark.ink is not a key of a theme."
        ])
        XCTAssertEqual(theme.dark.glassTint.alpha, 0)
    }

    func testAFileThatIsNotThereIsAFault() throws {
        let theme = ThemeFile(builtIn: try temporaryFolder().appendingPathComponent("theme.toml")).read()

        XCTAssertEqual(theme.faults, ["theme.toml cannot be read. Install Openspot again."])
    }

    func testTheBuiltInThemeTintsTheGlassAt60Percent() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

        let theme = ThemeFile(builtIn: url).read()

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.dark.glassTint, HexColor(text: "#00000099"))
        XCTAssertEqual(theme.light.glassTint, HexColor(text: "#FFFFFF99"))
    }

    func testACopyIsMadeOnceFromTheBuiltInThemeAndIsReadInItsPlace() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "dark.glass-tint = \"#00000099\"\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let file = ThemeFile(builtIn: builtIn, copy: folder.appendingPathComponent("themes/openspot.theme/theme.toml"))

        let copy = try file.makeCopy()
        try "dark.glass-tint = \"#00000033\"\n".write(to: copy, atomically: true, encoding: .utf8)
        XCTAssertEqual(try file.makeCopy(), copy)

        XCTAssertEqual(file.read().dark.glassTint, HexColor(text: "#00000033"))
    }

    func testTheCopyLivesBesideTheConfig() {
        let file = ThemeFile.standard(environment: ["OPENSPOT_CONFIG": "/tmp/openspot-config"], builtIn: nil)

        XCTAssertEqual(file.copy?.path, "/tmp/openspot-config/themes/openspot.theme/theme.toml")
    }

    func testThemeReloadIsAVerbOfItsOwnNoun() {
        XCTAssertEqual(CommandLineCall(arguments: ["theme", "reload"], environment: [:])?.value as? ThemeCall, .reload)
        XCTAssertEqual(CommandLineCall(arguments: ["theme", "open"], environment: [:])?.value as? ThemeCall, .open)
        XCTAssertNil(CommandLineCall(arguments: ["app", "theme"], environment: [:])?.value as? AppCall)
    }
}
