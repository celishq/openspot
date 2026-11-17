import XCTest
@testable import OpenspotCore

final class ThemeTests: XCTestCase {
    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

    func testAThemeGivesEachAppearanceAndBothItsValuesFromSections() {
        let theme = Theme(text: """
        [dark]
        glass-tint = "#00000099"
        glyph-on-solid = "accent"
        fill = 0.1

        [light]
        ink = "#FFFFFF"
        disc = 0

        [shared]
        good = "green"
        hover = 0.08
        """)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.look.dark.glassTint, .hex(HexColor(red: 0, green: 0, blue: 0, alpha: 0.6)))
        XCTAssertEqual(theme.look.dark.glyphOnSolid, .accent)
        XCTAssertEqual(theme.look.dark.fill, 0.1)
        XCTAssertEqual(theme.look.light.ink, .hex(HexColor(red: 1, green: 1, blue: 1)))
        XCTAssertEqual(theme.look.light.disc, 0)
        XCTAssertEqual(theme.look.shared.good, .green)
        XCTAssertEqual(theme.look.shared.hover, 0.08)
    }

    func testAThemeNamesEachValueItCannotRead() {
        let theme = Theme(text: """
        dark.glass-tint = "#00000099"

        [dark]
        glass-tint = "black"
        fill = 2
        size = 3

        [glass]
        variant = "frosted"
        backdrop-blur = -1
        fade-reach = 0.5
        edge-far = 3
        tint = "#000000"
        """)

        XCTAssertEqual(theme.faults, [
            "theme.toml: dark.glass-tint is not a key of a theme.",
            "theme.toml: [dark] glass-tint is a colour such as #00000099.",
            "theme.toml: [dark] fill is a strength from 0 to 1, such as 0.2.",
            "theme.toml: [dark] size is not a key of a theme.",
            "theme.toml: [glass] variant is clear or regular.",
            "theme.toml: [glass] backdrop-blur is a number of points from 0 to 100, such as 3.",
            "theme.toml: [glass] fade-reach is a number from 1 to 10, such as 3.",
            "theme.toml: [glass] edge-far is a strength from 0 to 1, such as 0.2.",
            "theme.toml: [glass] tint is not a key of a theme."
        ])
        XCTAssertEqual(theme.look.glass, Theme().look.glass)
        XCTAssertEqual(theme.look.dark.glassTint, Theme().look.dark.glassTint)
        XCTAssertEqual(theme.look.dark.fill, 0)
    }

    func testAThemeGivesTheGlassItsVariantBlurReachAndEdges() {
        let theme = Theme(text: """
        [glass]
        variant = "regular"
        backdrop-blur = 8
        fade-reach = 2.5
        edge-near = 0.9
        edge-middle = 0.6
        edge-far = 0.3
        """)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.look.glass.variant, .regular)
        XCTAssertEqual(theme.look.glass.backdropBlur, 8)
        XCTAssertEqual(theme.look.glass.fadeReach, 2.5)
        XCTAssertEqual(theme.look.glass.edgeStrengths, [0.9, 0.6, 0.3])
    }

    func testAThemeGivesTheSizesTypeAndMotionFromSections() {
        let theme = Theme(text: """
        [space]
        cell = 70
        padding = 20
        list-row = 44

        [radius]
        card = 30
        window = 12

        [type]
        title = 15
        detail = 12

        [motion]
        grow = 0.3
        press-bounce = 0.4
        lifted-scale = 1.1
        """)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.layout.space.cell, 70)
        XCTAssertEqual(theme.layout.space.padding, 20)
        XCTAssertEqual(theme.layout.space.listRow, 44)
        XCTAssertEqual(theme.layout.space.rowGap, Theme().layout.space.rowGap)
        XCTAssertEqual(theme.layout.radius.card, 30)
        XCTAssertEqual(theme.layout.radius.window, 12)
        XCTAssertEqual(theme.layout.type.title, 15)
        XCTAssertEqual(theme.layout.type.detail, 12)
        XCTAssertEqual(theme.layout.motion.grow, 0.3)
        XCTAssertEqual(theme.layout.motion.pressBounce, 0.4)
        XCTAssertEqual(theme.layout.motion.liftedScale, 1.1)
    }

    func testAThemeNamesEachSizeAndMotionItCannotRead() {
        let theme = Theme(text: """
        [space]
        padding = -1
        cell = "big"

        [radius]
        card = -2

        [type]
        title = "large"

        [motion]
        grow = -0.1
        press-bounce = 2
        pressed-scale = 0
        """)

        XCTAssertEqual(theme.faults, [
            "theme.toml: [space] padding is a number of points from 0 to 100, such as 3.",
            "theme.toml: [space] cell is a number of points from 0 to 100, such as 3.",
            "theme.toml: [radius] card is a number of points from 0 to 100, such as 3.",
            "theme.toml: [type] title is a number of points from 0 to 100, such as 3.",
            "theme.toml: [motion] grow is a time from 0 to 2 seconds, such as 0.2.",
            "theme.toml: [motion] press-bounce is a strength from 0 to 1, such as 0.2.",
            "theme.toml: [motion] pressed-scale is a scale from 0.5 to 2, such as 1.04."
        ])
        XCTAssertEqual(theme.layout.space, Theme().layout.space)
        XCTAssertEqual(theme.layout.radius, Theme().layout.radius)
        XCTAssertEqual(theme.layout.type, Theme().layout.type)
        XCTAssertEqual(theme.layout.motion, Theme().layout.motion)
    }

    func testAThemeKeepsEachNumberInTheRangeOfItsKind() {
        let theme = Theme(text: """
        [space]
        cell = 200
        padding = 60

        [glass]
        fade-reach = 20

        [motion]
        grow = 5
        pressed-scale = 3
        """)

        XCTAssertEqual(theme.faults, [
            "theme.toml: [space] cell is a number of points from 0 to 100, such as 3.",
            "theme.toml: [glass] fade-reach is a number from 1 to 10, such as 3.",
            "theme.toml: [motion] grow is a time from 0 to 2 seconds, such as 0.2.",
            "theme.toml: [motion] pressed-scale is a scale from 0.5 to 2, such as 1.04."
        ])
        XCTAssertEqual(theme.layout.space.cell, Theme().layout.space.cell)
        XCTAssertEqual(theme.layout.space.padding, 60)
    }

    func testAFileThatIsNotThereIsAFault() throws {
        let theme = ThemeFolder.read(builtIn: try temporaryFolder().appendingPathComponent("theme.toml"))

        XCTAssertEqual(theme.faults, ["theme.toml cannot be read. Install Openspot again."])
    }

    func testTheBuiltInThemeSetsEveryKeyOnce() throws {
        let document = try ConfigDocument(text: String(contentsOf: builtInURL, encoding: .utf8))

        let theme = ThemeFolder.read(builtIn: builtInURL)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(document.sections.flatMap { section in section.keys.map { "[\(section.name)] \($0)" } }.sorted(), Theme.keys.map(\.name))
        XCTAssertEqual(theme.look.dark.glassTint, .hex(HexColor(red: 0, green: 0, blue: 0, alpha: 0.6)))
        XCTAssertEqual(theme.look.light.glassTint, ThemeColor(text: "#FFFFFF99"))
        XCTAssertEqual(theme.look.glass.variant, .clear)
        XCTAssertEqual(theme.look.glass.backdropBlur, 3)
        XCTAssertEqual(theme.look.glass.fadeReach, 3)
        XCTAssertEqual(theme.look.glass.edgeStrengths, [1, 0.7, 0.45])
        XCTAssertEqual(theme.layout.space, Theme().layout.space)
        XCTAssertEqual(theme.layout.radius, Theme().layout.radius)
        XCTAssertEqual(theme.layout.type, Theme().layout.type)
        XCTAssertEqual(theme.layout.motion, Theme().layout.motion)
        XCTAssertEqual([theme.layout.space.cell, theme.layout.space.columnGap, theme.layout.space.rowGap, theme.layout.space.padding], [64, 11, 12, 13])
        XCTAssertEqual([theme.layout.radius.card, theme.layout.radius.window], [26, 16])
        XCTAssertEqual([theme.layout.type.title, theme.layout.type.detail], [13, 11])
        XCTAssertEqual([theme.layout.motion.grow, theme.layout.motion.shrink, theme.layout.motion.move], [0.15, 0.2, 0.25])
    }

    func testEachShippedThemeReadsWithNoFault() throws {
        let shipped = builtInURL.deletingLastPathComponent().deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: shipped, includingPropertiesForKeys: nil).filter { $0.pathExtension == "theme" }.map { $0.appendingPathComponent("theme.toml") }

        XCTAssertGreaterThan(files.count, 1)
        for file in files {
            XCTAssertEqual(ThemeFolder.read(builtIn: builtInURL, copy: file).faults, [], file.path)
        }
    }

    func testThePromptQuotesTheNameOfTheThemeForTheShell() {
        let name = "Say \"hi\" $HOME `date` it's"
        let own = ThemePrompt(theme: name, folder: URL(fileURLWithPath: "/themes"), isBuiltIn: false, base: nil, app: "/bin/openspot").asking("")
        let builtIn = ThemePrompt(theme: name, folder: URL(fileURLWithPath: "/themes"), isBuiltIn: true, base: nil, app: "/bin/openspot").asking("")
        let quoted = "'Say \"hi\" $HOME `date` it'\\''s'"

        XCTAssertTrue(own.contains("theme use \(quoted). "), own)
        XCTAssertTrue(builtIn.contains("theme duplicate \(quoted). "), builtIn)
    }

    func testACopyOverridesTheBuiltInThemeKeyByKey() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[shared]\nhover = 0.08\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try "[dark]\nfill = 0.3\nsize = 1\n".write(to: copy, atomically: true, encoding: .utf8)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)
        XCTAssertEqual(theme.look.dark.fill, 0.3)
        XCTAssertEqual(theme.look.dark.ink, ThemeColor(text: "#FFFFFF"))
        XCTAssertEqual(theme.look.shared.hover, 0.08)
        XCTAssertEqual(theme.faults, ["theme.toml: [dark] size is not a key of a theme."])
    }

    func testACopyThatCannotBeReadIsAFaultAndKeepsTheBuiltInLook() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[shared]\nhover = 0.08\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try Data([0xC3, 0x28]).write(to: copy)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)

        XCTAssertEqual(theme.look.shared.hover, 0.08)
        XCTAssertEqual(theme.faults, ["theme.toml cannot be read at \(copy.path), so Openspot keeps the look of the app. Save it as text, or delete it."])
    }
}
