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
        let theme = ThemeFile(url: try temporaryFolder().appendingPathComponent("theme.toml")).read()

        XCTAssertEqual(theme.faults, ["theme.toml cannot be read. Install Openspot again."])
    }

    func testTheBuiltInThemeTintsTheGlassAt60Percent() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

        let theme = ThemeFile(url: url).read()

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.dark.glassTint, HexColor(text: "#00000099"))
        XCTAssertEqual(theme.light.glassTint, HexColor(text: "#FFFFFF99"))
    }

    func testThemeReloadIsAVerbOfItsOwnNoun() {
        XCTAssertEqual(CommandLineCall(arguments: ["theme", "reload"], environment: [:])?.value as? ThemeCall, .reload)
        XCTAssertNil(CommandLineCall(arguments: ["app", "theme"], environment: [:])?.value as? AppCall)
    }
}
