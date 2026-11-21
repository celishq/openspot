import XCTest
@testable import OpenspotCore

final class ThemeTests: XCTestCase {
    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")
    private let dracula = """
    [dark]
    background = "#282A36"
    ink = "#F8F8F2"
    accent = "#BD93F9"
    highlight = "#FF79C6"
    bad = "#FF5555"

    [light]
    background = "#FFFBEB"
    ink = "#1F1F1F"
    accent = "#644AC9"
    highlight = "#A3144D"

    [look]
    glass = "regular"
    backdrop = "tint"
    reach = "screen"
    corner = 20
    density = 0.5
    type = 15
    speed = 2
    """

    func testTheShortFormGivesEachLookItsColoursAndTheLookItsChoices() {
        let theme = Theme(text: dracula)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.colours.dark.background, ThemeColor(text: "#282A36"))
        XCTAssertEqual(theme.colours.dark.ink, ThemeColor(text: "#F8F8F2"))
        XCTAssertEqual(theme.colours.dark.accent, ThemeColor(text: "#BD93F9"))
        XCTAssertEqual(theme.colours.light.accent, ThemeColor(text: "#644AC9"))
        XCTAssertEqual(theme.colours.dark.highlight, ThemeColor(text: "#FF79C6"))
        XCTAssertEqual(theme.colours.dark.bad, ThemeColor(text: "#FF5555"))
        XCTAssertEqual(theme.colours.light.bad, .red)
        XCTAssertEqual(theme.colours.dark.good, .green)
        XCTAssertEqual(theme.colours.glass, .regular)
        XCTAssertEqual(theme.layout.backdrop.style, .tint)
        XCTAssertEqual(theme.layout.backdrop.reach, .screen)
        XCTAssertEqual(theme.layout.radius.card, 20)
        XCTAssertEqual(theme.layout.type.body, 15)
    }

    func testTheColoursOfALookFollowFromItsChoices() {
        let dark = Theme(text: dracula).colours.dark

        XCTAssertEqual(dark.solid, ThemeColor(text: "#FF79C6"))
        XCTAssertEqual(dark.onSolid, ThemeColor(text: "#282A36"))
        XCTAssertEqual(dark.glyphOnSolid, dark.onSolid)
        XCTAssertEqual(dark.glassTint, ThemeColor(text: "#282A36E6"))
        XCTAssertEqual(dark.glass, dark.glassTint)
        XCTAssertEqual(dark.cornerFill, ThemeColor(text: "#52535C"))
        XCTAssertEqual(dark.window, ThemeColor(text: "#494B54"))
        XCTAssertEqual(dark.confirm, ThemeColor(text: "#FF5555"))
        XCTAssertEqual(dark.onConfirm, ThemeColor(text: "#282A36"))
        XCTAssertEqual(dark.backdropTint, ThemeColor(text: "#282A3699"))
    }

    func testTheShadowOfACardIsAFaintBlackThatAThemeCanSetAndSize() {
        let openspot = Theme(text: "")
        let set = Theme(text: "[light]\ncard-shadow = \"#11223344\"\n\n[advanced]\ncard-shadow-size = 20\n")

        XCTAssertEqual(openspot.colours.light.cardShadow, ThemeColor(text: "#000000")!.with(alpha: 0.04))
        XCTAssertEqual(openspot.colours.dark.cardShadow, ThemeColor(text: "#000000")!.with(alpha: 0.15))
        XCTAssertEqual(openspot.layout.backdrop.shadow, 24)
        XCTAssertEqual(set.colours.light.cardShadow, ThemeColor(text: "#11223344"))
        XCTAssertEqual(set.layout.backdrop.shadow, 20)
    }

    func testOpenspotLiquidIsOpenspotWithClearTintedGlass() throws {
        let liquid = builtInURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Openspot Liquid.theme/theme.toml")
        let lines = { (text: String) in text.split(separator: "\n").filter { !$0.hasPrefix("glass") } }
        let frosted = try String(contentsOf: builtInURL, encoding: .utf8)
        let clear = try String(contentsOf: liquid, encoding: .utf8)

        XCTAssertEqual(lines(clear), lines(frosted))
        XCTAssertEqual(Theme(text: frosted).colours.glass, .regular)
        XCTAssertEqual(Theme(text: frosted).colours.light.glassTint.sample.alpha, 0)
        XCTAssertEqual(Theme(text: clear).colours.glass, .clear)
        XCTAssertEqual(Theme(text: clear).colours.light.glassTint, ThemeColor(text: "#C4C4C473"))
    }

    func testAnOnColourIsTheBackgroundOrTheInkWhicheverReadsBetter() {
        let light = Theme(text: "[light]\nbackground = \"#EFF1F5\"\nink = \"#4C4F69\"\nhighlight = \"#EA76CB\"\n").colours.light

        XCTAssertEqual(light.onSolid, ThemeColor(text: "#4C4F69"))
    }

    func testEachStrengthKeepsTheVisibleStepOfOpenspot() {
        let theme = Theme(text: dracula)

        XCTAssertEqual(theme.colours.dark.fill, 0.097, accuracy: 0.001)
        XCTAssertEqual(theme.colours.dark.selected, 0.263, accuracy: 0.001)
        XCTAssertEqual(theme.colours.dark.track, 0.236, accuracy: 0.001)
        XCTAssertEqual(theme.colours.light.fill, 0.082, accuracy: 0.001)
        XCTAssertEqual(theme.colours.light.disc, 0)
    }

    func testANearWhiteLookTakesALargerStrengthForTheSameStep() {
        let light = Theme(text: "[light]\nbackground = \"#FDF6E3\"\nink = \"#586E75\"\n").colours.light

        XCTAssertGreaterThan(light.fill, Theme().colours.light.fill)
        XCTAssertGreaterThan(light.selected, Theme().colours.light.selected)
    }

    func testSecondaryTextReadsAtFourAndAHalfToOneOverTheRealSurface() {
        let theme = Theme(text: "[dark]\nbackground = \"#282C34\"\nink = \"#ABB2BF\"\n\n[look]\nglass = \"regular\"\n")
        let surface = HexColor(red: 1, green: 1, blue: 1).mixed(with: HexColor(text: "#282C34")!, by: 0.9)
        let text = surface.mixed(with: HexColor(text: "#ABB2BF")!, by: theme.colours.dark.secondary)

        XCTAssertGreaterThanOrEqual(text.contrast(with: surface), 4.5)
        XCTAssertGreaterThan(theme.colours.dark.secondary, 0.7)
    }

    func testOpenspotsChoicesGiveItsMeasuredValues() {
        let look = Theme().colours

        XCTAssertEqual(look.dark.glassTint, ThemeColor(text: "#000000E6"))
        XCTAssertEqual(look.light.glassTint, ThemeColor(text: "#FFFFFFE6"))
        XCTAssertEqual(look.dark.glass, look.dark.glassTint)
        XCTAssertEqual(look.light.glass, look.light.glassTint)
        XCTAssertEqual([look.dark.cornerFill, look.light.cornerFill], [ThemeColor(text: "#333333"), ThemeColor(text: "#FAFAFA")])
        XCTAssertEqual([look.dark.window, look.light.window], [ThemeColor(text: "#292929"), ThemeColor(text: "#EDEDED")])
        XCTAssertEqual([look.dark.onSolid, look.light.onSolid], [ThemeColor(text: "#000000"), ThemeColor(text: "#FFFFFF")])
        XCTAssertEqual([look.dark.fill, look.dark.selected, look.dark.disc, look.dark.chip, look.dark.control, look.dark.track], [0.1, 0.22, 0.2, 0.25, 0.2, 0.2])
        XCTAssertEqual([look.light.fill, look.light.selected, look.light.disc, look.light.chip, look.light.control, look.light.track], [0.08, 0.12, 0, 0.1, 0.09, 0.12])
        XCTAssertEqual([look.dark.secondary, look.light.secondary], [0.7, 0.7])
        XCTAssertEqual(look.dark.accent, .accent)
        XCTAssertEqual(look.glass, .regular)
    }

    func testOpenspotsChoicesGiveItsMeasuredSizes() {
        let layout = Theme().layout

        XCTAssertEqual([layout.space.cell, layout.space.columnGap, layout.space.rowGap, layout.space.padding], [64, 11, 12, 13])
        XCTAssertEqual([layout.space.glyph, layout.space.listRow, layout.space.listRowGap, layout.space.menuRow, layout.space.menuPadding], [36, 40, 6, 32, 8])
        XCTAssertEqual([layout.radius.card, layout.radius.window, layout.radius.media, layout.radius.cornerMark], [26, 16, 8, 6])
        XCTAssertEqual([layout.type.title, layout.type.body, layout.type.detail, layout.type.input], [13, 13, 11, 14])
        XCTAssertEqual([layout.motion.grow, layout.motion.shrink, layout.motion.move, layout.motion.fadeIn, layout.motion.fadeOut, layout.motion.press, layout.motion.settle], [0.15, 0.2, 0.25, 0.1, 0.12, 0.2, 0.25])
        XCTAssertEqual([layout.motion.pressBounce, layout.motion.pressedScale, layout.motion.liftedScale, layout.motion.focusedScale], [0.2, 1.04, 1.05, 1.04])
        XCTAssertEqual(layout.backdrop.style, .blur)
        XCTAssertEqual(layout.backdrop.reach, .tiles)
        XCTAssertEqual([layout.backdrop.blur, layout.backdrop.size, layout.backdrop.padding], [1, 30, 0])
    }

    func testCornerDensityTypeAndSpeedScaleWhatFollowsThem() {
        let layout = Theme(text: dracula).layout

        let corners: [Double] = [20, 20.0 * 16 / 26, 20.0 * 8 / 26, 20.0 * 6 / 26]
        XCTAssertEqual([layout.radius.card, layout.radius.window, layout.radius.media, layout.radius.cornerMark], corners)
        XCTAssertEqual([layout.space.columnGap, layout.space.rowGap, layout.space.padding, layout.space.listRowGap, layout.space.menuPadding], [6, 6, 7, 3, 4])
        XCTAssertEqual([layout.space.cell, layout.space.glyph, layout.space.listRow, layout.space.menuRow], [64, 36, 40, 32])
        XCTAssertEqual([layout.type.title, layout.type.body, layout.type.detail, layout.type.input], [15, 15, 13, 16])
        XCTAssertEqual([layout.motion.grow, layout.motion.shrink, layout.motion.move], [0.075, 0.1, 0.125])
        XCTAssertEqual(layout.motion.pressBounce, 0.2)
    }

    func testAnExactValueTakesThePlaceOfItsRuleAndFeedsTheRulesAfterIt() {
        let theme = Theme(text: """
        [dark]
        solid = "#FFFF00"
        fill = 0.3

        [advanced]
        cell = 70
        window-corner = 6
        press-bounce = 0
        halo-size = 80
        """)

        XCTAssertEqual(theme.faults, [])
        XCTAssertEqual(theme.colours.dark.solid, ThemeColor(text: "#FFFF00"))
        XCTAssertEqual(theme.colours.dark.onSolid, ThemeColor(text: "#000000"))
        XCTAssertEqual(theme.colours.dark.fill, 0.3)
        XCTAssertEqual(theme.colours.light.fill, 0.08)
        XCTAssertEqual(theme.layout.space.cell, 70)
        XCTAssertEqual(theme.layout.radius.window, 6)
        XCTAssertEqual(theme.layout.radius.card, 26)
        XCTAssertEqual(theme.layout.motion.pressBounce, 0)
        XCTAssertEqual(theme.layout.backdrop.size, 80)
    }

    func testAnOldKeyIsNotAKeyOfATheme() {
        let theme = Theme(text: """
        [shared]
        accent = "#FF9F0A"

        [dark]
        foil = "#FFFFFF"
        preview = "#4D4D4D"

        [space]
        cell = 70
        """)

        XCTAssertEqual(theme.faults, [
            "theme.toml: [shared] accent is not a key of a theme.",
            "theme.toml: [dark] foil is not a key of a theme.",
            "theme.toml: [dark] preview is not a key of a theme.",
            "theme.toml: [space] cell is not a key of a theme."
        ])
        XCTAssertEqual(theme.colours, Theme().colours)
        XCTAssertEqual(theme.layout, Theme().layout)
    }

    func testAThemeNamesEachValueItCannotRead() {
        let theme = Theme(text: """
        dark.ink = "#FFFFFF"

        [dark]
        background = "black"
        fill = 2

        [look]
        glass = "frosted"
        backdrop = "fog"
        reach = "window"
        corner = -1
        density = 9
        speed = 0

        [advanced]
        halo-size = 91
        grow = 5
        pressed-scale = 3
        """)

        XCTAssertEqual(theme.faults, [
            "theme.toml: dark.ink is not a key of a theme.",
            "theme.toml: [dark] background is a colour such as #00000099.",
            "theme.toml: [dark] fill is a strength from 0 to 1, such as 0.2.",
            "theme.toml: [look] glass is clear or regular.",
            "theme.toml: [look] backdrop is blur or tint.",
            "theme.toml: [look] reach is tiles or screen.",
            "theme.toml: [look] corner is a number of points from 0 to 100, such as 3.",
            "theme.toml: [look] density is a factor from 0.25 to 4, such as 1.5.",
            "theme.toml: [look] speed is a factor from 0.25 to 4, such as 1.5.",
            "theme.toml: [advanced] halo-size is a number of points from 16 to 90, such as 30.",
            "theme.toml: [advanced] grow is a time from 0 to 2 seconds, such as 0.2.",
            "theme.toml: [advanced] pressed-scale is a scale from 0.5 to 2, such as 1.04."
        ])
        XCTAssertEqual(theme.colours, Theme().colours)
        XCTAssertEqual(theme.layout, Theme().layout)
    }

    func testAFileThatIsNotThereIsAFault() throws {
        let theme = ThemeFolder.read(builtIn: try temporaryFolder().appendingPathComponent("theme.toml"))

        XCTAssertEqual(theme.faults, ["theme.toml cannot be read. Install Openspot again."])
    }

    func testTheBuiltInThemeSetsEachChoiceAndDrawsTodaysLook() throws {
        let document = try ConfigDocument(text: String(contentsOf: builtInURL, encoding: .utf8))
        let named = Set(document.sections.flatMap { section in section.keys.map { "[\(section.name)] \($0)" } })

        let theme = ThemeFolder.read(builtIn: builtInURL)

        XCTAssertEqual(theme.faults, [])
        XCTAssertTrue(Set(Theme.keys.map(\.name)).subtracting(["[dark] good", "[dark] warn", "[dark] bad", "[light] good", "[light] warn", "[light] bad"]).isSubset(of: named), named.description)
        XCTAssertEqual(Theme(text: Self.choices(of: document)).colours, Theme().colours)
        XCTAssertEqual(theme.layout, Theme().layout)
        XCTAssertEqual(theme.colours.light.solid, ThemeColor(text: "#1F1F1F"))
        XCTAssertEqual([theme.colours.dark.glassTint, theme.colours.light.glassTint], [ThemeColor(text: "#2C2C2E00"), ThemeColor(text: "#C4C4C400")])
        XCTAssertEqual(theme.colours.dark.glyphOnSolid, .accent)
        XCTAssertEqual([theme.colours.dark.confirm, theme.colours.light.confirm], [ThemeColor(text: "#C72924"), ThemeColor(text: "#C72924")])
        XCTAssertEqual([theme.colours.dark.onConfirm, theme.colours.light.onConfirm], [ThemeColor(text: "#FFFFFF"), ThemeColor(text: "#FFFFFF")])
    }

    func testEachShippedThemeReadsWithNoFault() throws {
        let shipped = builtInURL.deletingLastPathComponent().deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: shipped, includingPropertiesForKeys: nil).filter { $0.pathExtension == "theme" }.map { $0.appendingPathComponent("theme.toml") }

        XCTAssertGreaterThan(files.count, 1)
        for file in files {
            XCTAssertEqual(ThemeFolder.read(builtIn: builtInURL, copy: file).faults, [], file.path)
        }
    }

    func testThePromptNamesTheShortKeys() {
        let prompt = ThemePrompt(theme: "Dusk", folder: URL(fileURLWithPath: "/themes"), isBuiltIn: false, base: nil, app: "/bin/openspot").asking("")

        XCTAssertTrue(prompt.contains("[dark] background, ink, accent, highlight, good, warn, bad"), prompt)
        XCTAssertTrue(prompt.contains("[look] glass, backdrop, reach, corner, density, type, speed"), prompt)
        XCTAssertFalse(prompt.contains("corner-fill"), prompt)
    }

    func testThePromptQuotesTheNameOfTheThemeForTheShell() {
        let name = "Say \"hi\" $HOME `date` it's"
        let own = ThemePrompt(theme: name, folder: URL(fileURLWithPath: "/themes"), isBuiltIn: false, base: nil, app: "/bin/openspot").asking("")
        let builtIn = ThemePrompt(theme: name, folder: URL(fileURLWithPath: "/themes"), isBuiltIn: true, base: nil, app: "/bin/openspot").asking("")
        let quoted = "'Say \"hi\" $HOME `date` it'\\''s'"

        XCTAssertTrue(own.contains("theme use \(quoted). "), own)
        XCTAssertTrue(builtIn.contains("theme duplicate \(quoted). "), builtIn)
    }

    func testACopyOverridesTheChoicesOfTheBuiltInThemeKeyByKey() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nink = \"#EEEEEE\"\nbackground = \"#111111\"\n\n[look]\ncorner = 20\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try "[dark]\nbackground = \"#222222\"\nsize = 1\n".write(to: copy, atomically: true, encoding: .utf8)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)

        XCTAssertEqual(theme.colours.dark.background, ThemeColor(text: "#222222"))
        XCTAssertEqual(theme.colours.dark.ink, ThemeColor(text: "#EEEEEE"))
        XCTAssertEqual(theme.layout.radius.card, 20)
        XCTAssertEqual(theme.faults, ["theme.toml: [dark] size is not a key of a theme."])
    }

    func testAnExactValueHoldsOnlyInTheFileThatSetsIt() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nwindow = \"#292929\"\n\n[advanced]\ncell = 70\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try "[dark]\nbackground = \"#282A36\"\nink = \"#F8F8F2\"\n".write(to: copy, atomically: true, encoding: .utf8)

        XCTAssertEqual(ThemeFolder.read(builtIn: builtIn).colours.dark.window, ThemeColor(text: "#292929"))
        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)

        XCTAssertEqual(theme.colours.dark.window, ThemeColor(text: "#494B54"))
        XCTAssertEqual(theme.layout.space.cell, 64)
    }

    func testACopyThatCannotBeReadIsAFaultAndKeepsTheBuiltInLook() throws {
        let folder = try temporaryFolder()
        let builtIn = folder.appendingPathComponent("built-in.toml")
        try "[dark]\nwindow = \"#123456\"\n".write(to: builtIn, atomically: true, encoding: .utf8)
        let copy = folder.appendingPathComponent("theme.toml")
        try Data([0xC3, 0x28]).write(to: copy)

        let theme = ThemeFolder.read(builtIn: builtIn, copy: copy)

        XCTAssertEqual(theme.colours.dark.window, ThemeColor(text: "#123456"))
        XCTAssertEqual(theme.faults, ["theme.toml cannot be read at \(copy.path), so Openspot keeps the look of the app. Save it as text, or delete it."])
    }

    private static func choices(of document: ConfigDocument) -> String {
        let keys = Set(Theme.keys.map(\.name))
        return document.sections.map { section in
            (["[\(section.name)]"] + section.keys.filter { keys.contains("[\(section.name)] \($0)") }.map { "\($0) = \(section[$0]!.text)" }).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}
