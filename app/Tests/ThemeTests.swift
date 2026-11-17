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
        XCTAssertEqual(theme.dark.glassTint, .hex(HexColor(red: 0, green: 0, blue: 0, alpha: 0.6)))
        XCTAssertEqual(theme.dark.glyphOnSolid, .accent)
        XCTAssertEqual(theme.dark.fill, 0.1)
        XCTAssertEqual(theme.light.ink, .hex(HexColor(red: 1, green: 1, blue: 1)))
        XCTAssertEqual(theme.light.disc, 0)
        XCTAssertEqual(theme.shared.good, .green)
        XCTAssertEqual(theme.shared.hover, 0.08)
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
        XCTAssertEqual(theme.glass, Theme().glass)
        XCTAssertEqual(theme.dark.glassTint, Theme().dark.glassTint)
        XCTAssertEqual(theme.dark.fill, 0)
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
        XCTAssertEqual(theme.glass.variant, .regular)
        XCTAssertEqual(theme.glass.backdropBlur, 8)
        XCTAssertEqual(theme.glass.fadeReach, 2.5)
        XCTAssertEqual(theme.glass.edgeStrengths, [0.9, 0.6, 0.3])
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
        XCTAssertEqual(theme.space.cell, 70)
        XCTAssertEqual(theme.space.padding, 20)
        XCTAssertEqual(theme.space.listRow, 44)
        XCTAssertEqual(theme.space.rowGap, Theme().space.rowGap)
        XCTAssertEqual(theme.radius.card, 30)
        XCTAssertEqual(theme.radius.window, 12)
        XCTAssertEqual(theme.type.title, 15)
        XCTAssertEqual(theme.type.detail, 12)
        XCTAssertEqual(theme.motion.grow, 0.3)
        XCTAssertEqual(theme.motion.pressBounce, 0.4)
        XCTAssertEqual(theme.motion.liftedScale, 1.1)
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
        XCTAssertEqual(theme.space, Theme().space)
        XCTAssertEqual(theme.radius, Theme().radius)
        XCTAssertEqual(theme.type, Theme().type)
        XCTAssertEqual(theme.motion, Theme().motion)
    }

    func testAThemeKeepsEachNumberInTheRangeTheEditorOffers() {
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
        XCTAssertEqual(theme.space.cell, Theme().space.cell)
        XCTAssertEqual(theme.space.padding, 60)
        XCTAssertEqual(ThemeKind.points.value(200), .integer(100))
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
        XCTAssertEqual(theme.dark.glassTint, .hex(HexColor(red: 0, green: 0, blue: 0, alpha: 0.6)))
        XCTAssertEqual(theme.light.glassTint, ThemeColor(text: "#FFFFFF99"))
        XCTAssertEqual(theme.glass.variant, .clear)
        XCTAssertEqual(theme.glass.backdropBlur, 3)
        XCTAssertEqual(theme.glass.fadeReach, 3)
        XCTAssertEqual(theme.glass.edgeStrengths, [1, 0.7, 0.45])
        XCTAssertEqual(theme.space, Theme().space)
        XCTAssertEqual(theme.radius, Theme().radius)
        XCTAssertEqual(theme.type, Theme().type)
        XCTAssertEqual(theme.motion, Theme().motion)
        XCTAssertEqual([theme.space.cell, theme.space.columnGap, theme.space.rowGap, theme.space.padding], [64, 11, 12, 13])
        XCTAssertEqual([theme.radius.card, theme.radius.window], [26, 16])
        XCTAssertEqual([theme.type.title, theme.type.detail], [13, 11])
        XCTAssertEqual([theme.motion.grow, theme.motion.shrink, theme.motion.move], [0.15, 0.2, 0.25])
    }

    func testACopyOverridesTheBuiltInThemeKeyByKey() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[shared]\nhover = 0.08\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try "[dark]\nfill = 0.3\nsize = 1\n".write(to: copy, atomically: true, encoding: .utf8)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)
        XCTAssertEqual(theme.dark.fill, 0.3)
        XCTAssertEqual(theme.dark.ink, ThemeColor(text: "#FFFFFF"))
        XCTAssertEqual(theme.shared.hover, 0.08)
        XCTAssertEqual(theme.faults, ["theme.toml: [dark] size is not a key of a theme."])
    }

    func testACopyThatCannotBeReadIsAFaultAndKeepsTheBuiltInLook() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[shared]\nhover = 0.08\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try Data([0xC3, 0x28]).write(to: copy)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)

        XCTAssertEqual(theme.shared.hover, 0.08)
        XCTAssertEqual(theme.faults, ["theme.toml cannot be read at \(copy.path), so Openspot keeps the look of the app. Save it as text, or delete it."])
    }

    func testTheRowsOfTheBuiltInFileHoldEachKeyOnceWithItsKindAndDrawTheSameTheme() throws {
        let text = try String(contentsOf: builtInURL, encoding: .utf8)

        let rows = ThemeRow.rows(builtIn: text, own: nil)

        let names = rows.flatMap { row in row.cells.map(\.key.name) }
        XCTAssertEqual(names.sorted(), Theme.keys.map(\.name))
        XCTAssertEqual(Set(rows.filter { $0.group == "look" }.map { $0.cells.map(\.key.section) }), [["dark", "light"]])
        XCTAssertEqual(rows.first { $0.name == "variant" }?.kind, .variant)
        XCTAssertEqual(rows.first { $0.name == "padding" }?.kind, .points)
        XCTAssertEqual(rows.first { $0.name == "fade-reach" }?.kind, .reach)
        XCTAssertEqual(rows.first { $0.name == "grow" }?.kind, .seconds)
        XCTAssertEqual(rows.first { $0.name == "pressed-scale" }?.kind, .scale)
        XCTAssertEqual(rows.first { $0.name == "press-bounce" }?.kind, .strength)
        XCTAssertEqual(Theme(rows: rows), Theme(text: text))
    }

    func testARowOfAValueTheFileRefusesShowsTheValueTheThemeDraws() throws {
        let text = try String(contentsOf: builtInURL, encoding: .utf8)
        let own = "[motion]\ngrow = 3\n\n[dark]\nink = \"#XYZ\"\n\n[light]\nfill = 0.3\n"

        let rows = ThemeRow.rows(builtIn: text, own: own)

        let grow = ThemeKey(section: "motion", key: "grow")
        let ink = ThemeKey(section: "dark", key: "ink")
        XCTAssertEqual(rows.first { $0.id == grow }?.cells, [ThemeRow.Cell(key: grow, value: .number(0.15), isSet: false)])
        XCTAssertEqual(rows.first { $0.id == ink }?.cells.first, ThemeRow.Cell(key: ink, value: .string("#FFFFFF"), isSet: false))
        XCTAssertEqual(rows.first { $0.name == "fill" }?.cells.last?.value, .number(0.3))
        let drawn = Theme(text: own, over: Theme(text: text))
        XCTAssertEqual(drawn.faults.count, 2)
        XCTAssertEqual(Theme(rows: rows).motion, drawn.motion)
        XCTAssertEqual(Theme(rows: rows).dark, drawn.dark)
    }

    func testAChangedCellDrawsTheThemeWithItsValue() throws {
        var rows = ThemeRow.rows(builtIn: try String(contentsOf: builtInURL, encoding: .utf8), own: "[light]\nfill = 0.3\n")
        let index = try XCTUnwrap(rows.firstIndex { $0.name == "padding" })

        rows[index].change(.integer(21), at: ThemeKey(section: "space", key: "padding"))

        XCTAssertEqual(rows[index].cells, [ThemeRow.Cell(key: ThemeKey(section: "space", key: "padding"), value: .integer(21), isSet: true)])
        XCTAssertEqual(Theme(rows: rows).space.padding, 21)
        XCTAssertEqual(Theme(rows: rows).light.fill, 0.3)
    }

    func testAKindRoundsANumberIntoItsRange() {
        XCTAssertEqual(ThemeKind.points.value(13.4), .number(13.4))
        XCTAssertEqual(ThemeKind.points.value(13), .integer(13))
        XCTAssertEqual(ThemeKind.strength.value(0.123), .number(0.12))
        XCTAssertEqual(ThemeKind.strength.value(1.5), .number(1))
        XCTAssertEqual(ThemeKind.reach.value(0), .number(1))
        XCTAssertEqual(ConfigDocument.Value.integer(3).number, 3)
        XCTAssertNil(ConfigDocument.Value.string("#FFFFFF").number)
    }
}
