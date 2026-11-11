import XCTest
@testable import OpenspotCore

final class SpotArrangementTests: XCTestCase {
    private func commands(_ ids: String...) -> [Spot] {
        ids.map { Spot(id: $0, name: $0, url: URL(fileURLWithPath: "/bin/true")) }
    }

    private func choice(_ id: String, size: SpotSize? = nil, isOnGrid: Bool? = nil) -> SpotArrangement.Choice {
        SpotArrangement.Choice(id: id, size: size, isOnGrid: isOnGrid)
    }

    func testAChoiceOfSizeAloneMovesNothing() {
        let arrangement = SpotArrangement(choices: [choice("b", size: .small)])

        XCTAssertEqual(arrangement.ordered(commands("a", "b", "c")).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(arrangement.size(of: "b"), .small)
        XCTAssertNil(arrangement.size(of: "a"))
    }

    func testListedSpotsTakeTheOrderOfTheFile() {
        let arrangement = SpotArrangement(choices: [choice("c"), choice("a")])

        XCTAssertEqual(arrangement.ordered(commands("a", "b", "c")).map(\.id), ["c", "b", "a"])
    }

    func testASpotThatIsGoneIsKeptAndLeftOut() {
        var arrangement = SpotArrangement(choices: [choice("gone", size: .small), choice("a")])

        arrangement.arrange(["b", "a"])

        XCTAssertEqual(arrangement.ordered(commands("a", "b")).map(\.id), ["b", "a"])
        XCTAssertEqual(arrangement.size(of: "gone"), .small)
    }

    func testAChoiceKeepsItsPlaceWhenItChanges() {
        var arrangement = SpotArrangement()
        arrangement.arrange(["b", "a"])

        arrangement.set(size: .square, of: "a")
        arrangement.set(isOnGrid: false, of: "b")

        XCTAssertEqual(arrangement.choices, [choice("b", isOnGrid: false), choice("a", size: .square)])
    }

    func testTheConfigReadsTheChoices() {
        let config = Config(text: """
        panel_key = "cmd+k"

        [[spots]]
        id = "apps"
        size = "small"

        [[spots]]
        id = "files"
        grid = false
        global = false
        """)

        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.arrangement.choices, [
            choice("apps", size: .small),
            SpotArrangement.Choice(id: "files", isOnGrid: false, isGlobal: false)
        ])
        XCTAssertEqual(config.arrangement.isGlobal(of: "files"), false)
    }

    func testTheConfigKeepsTheSpotsThatThePersonPutInTheMenuBar() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-arrangement-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        try file.write(SpotArrangement(choices: [choice("apps", size: .small)]))

        try file.showInMenuBar("cups", true)
        try file.showInMenuBar("pulls", true)
        try file.showInMenuBar("pulls", false)

        let config = file.read()
        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.arrangement.menuBar, ["cups"])
        XCTAssertEqual(config.arrangement.size(of: "apps"), .small)
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"cups\"\ntray = true\n").arrangement.menuBar, ["cups"])
    }

    func testTheConfigReadsAndWritesTheLetterOfASpot() {
        let config = Config(text: "[[spots]]\nid = \"mail\"\nletter = \"M\"\n\n[[spots]]\nid = \"notes\"\nletter = \"\"\n\n[[spots]]\nid = \"bad\"\nletter = \"??\"\n")

        XCTAssertEqual(config.faults, ["config.toml: bad cannot use the letter ??."])
        XCTAssertEqual(config.arrangement.choices.map(\.letter), ["m", "", nil])
        XCTAssertEqual(Config(text: config.arrangement.text).arrangement.choices.map(\.letter), ["m", "", nil])
    }

    func testThePersonsLettersWinOverTheDefaultLetters() {
        let defaults = SpotArrangement(choices: [
            SpotArrangement.Choice(id: "apps", letter: "a"),
            SpotArrangement.Choice(id: "notes", letter: "n"),
            SpotArrangement.Choice(id: "files", letter: "f")
        ])
        let person = SpotArrangement(choices: [
            SpotArrangement.Choice(id: "mail", letter: "a"),
            SpotArrangement.Choice(id: "notes", letter: "")
        ])

        let letters = person.letters(over: defaults)

        XCTAssertEqual(letters.mapValues(\.name), ["mail": "a", "files": "f"])
    }

    func testGivingALetterTakesItFromTheSpotThatHeldIt() {
        let defaults = SpotArrangement(choices: [SpotArrangement.Choice(id: "notes", letter: "n")])
        var person = SpotArrangement(choices: [SpotArrangement.Choice(id: "mail", letter: "m")])

        let lost = person.give(CommandKey(name: "n"), to: "mail", over: defaults)

        XCTAssertEqual(lost, "notes")
        XCTAssertEqual(person.letters(over: defaults).mapValues(\.name), ["mail": "n"])
        XCTAssertNil(person.give(nil, to: "mail", over: defaults))
        XCTAssertEqual(person.letters(over: defaults).mapValues(\.name), [:])
    }

    func testTheConfigReportsWhatItCannotUseAndKeepsTheRest() {
        let config = Config(text: """
        [[spots]]
        size = "small"

        [[spots]]
        id = "a"
        size = "huge"
        color = "red"

        [[spots]]
        id = "b"
        size = "wide"
        """)

        XCTAssertEqual(config.arrangement.choices, [choice("a"), choice("b", size: .wide)])
        XCTAssertEqual(config.faults, [
            "config.toml: a spot needs an id.",
            "config.toml: a cannot use the size huge.",
            "config.toml: color is not a setting of a spot."
        ])
    }

    func testAFileKeepsItsKeyAndItsChoicesThroughEachWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-arrangement-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let arrangement = SpotArrangement(choices: [choice("b", size: .large, isOnGrid: false), choice("a")])

        try file.set("panel_key", to: "cmd+k")
        try file.write(arrangement)
        try file.set("panel_key", to: "cmd+j")
        try file.write(SpotArrangement(choices: arrangement.choices.reversed()))

        let config = file.read()
        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.panelKey, Shortcut(text: "cmd+j"))
        XCTAssertEqual(config.arrangement.choices, arrangement.choices.reversed())
    }

    func testASizeStepSkipsEachSizeThatChangesNothing() {
        let sizes: [SpotSize] = [.small, .small]

        XCTAssertEqual(SpotGrid().nextSize(of: 0, in: sizes, among: [.small, .wide, .strip]), .strip)
    }

    func testASizeStepTurnsBackToTheFirstSizeOrFindsNone() {
        XCTAssertNil(SpotGrid().nextSize(of: 0, in: [.strip], among: [.small, .wide, .strip]))
        XCTAssertEqual(SpotGrid().nextSize(of: 0, in: [.large, .large], among: [.strip, .large]), .strip)
    }

    func testASizeStepFindsNoneForASpotWithNoSizes() {
        XCTAssertNil(SpotGrid().nextSize(of: 0, in: [.large], among: []))
    }

    func testAMoveStepSkipsEachPlaceThatLeavesTheSpotWhereItIs() {
        let sizes: [SpotSize] = [.square, .small, .small, .wide, .small]

        XCTAssertEqual(SpotGrid().nextPlace(of: 0, in: sizes, step: 1), 1)
        XCTAssertEqual(SpotGrid().nextPlace(of: 1, in: [.small, .square, .small, .small, .square], step: 1), 3)
        XCTAssertNil(SpotGrid().nextPlace(of: 1, in: [.small, .square, .small], step: 1))
    }

    func testAMoveStepFindsNoPlaceAtTheEndOfTheGrid() {
        XCTAssertNil(SpotGrid().nextPlace(of: 1, in: [.wide, .wide], step: 1))
        XCTAssertNil(SpotGrid().nextPlace(of: 0, in: [.wide, .wide], step: -1))
    }

    func testASpotOffersTheSizesItCanTake() {
        let url = URL(fileURLWithPath: "/bin/true")

        XCTAssertEqual(Spot(id: "a", name: "A", url: url).sizes.count, 5)
        XCTAssertEqual(Spot(id: "w", name: "W", url: url, kind: .widget).sizes, [])
    }

    func testOnlyTheBuiltInsThatSayItChangeKeysReadOnAnUpdateOrTakeAShake() {
        let url = URL(fileURLWithPath: "/bin/true")
        let commands = ShippedSpot.commands(folder: url, guide: url, app: "")
        let settings = commands.first { $0.id == ShippedSpot.settingsID }
        let spots = commands.first { $0.id == ShippedSpot.spotsID }

        XCTAssertEqual(commands.filter(\.setsKeys).map(\.id), [ShippedSpot.settingsID])
        XCTAssertEqual(settings?.shipped?.takesShake("key:apps:open"), true)
        XCTAssertEqual(settings?.shipped?.takesShake("setting:apps:size"), false)
        XCTAssertEqual(spots?.shipped?.takesShake("key:apps:open"), false)
    }

    func testSpotsOpensNewSpotFromARowReviewsCodeAndChangesSpotsWhileSettingsChangesASetting() {
        let url = URL(fileURLWithPath: "/bin/true")
        let commands = ShippedSpot.commands(folder: url, guide: url, app: "")
        let spots = commands.first { $0.id == ShippedSpot.spotsID }
        let settings = commands.first { $0.id == ShippedSpot.settingsID }

        XCTAssertEqual(spots?.rowOpens, [CatalogSpot.buildRun: ShippedSpot.newID])
        XCTAssertEqual(spots?.reviewAction, CatalogSpot.reviewID)
        XCTAssertEqual(commands.filter(\.changesSpots).map(\.id), [ShippedSpot.spotsID])
        XCTAssertEqual(settings?.shipped?.settingChange(of: "setting:apps:size")?.spot, "apps")
        XCTAssertNil(spots?.shipped?.settingChange(of: "setting:apps:size"))
    }

    func testNewSpotGivesTheAgentPromptAndSettingsOpensWithTheSettingsKey() {
        let url = URL(fileURLWithPath: "/bin/true")
        let commands = ShippedSpot.commands(folder: url, guide: url, app: "")

        XCTAssertEqual(commands.filter { $0.agentPrompt != nil }.map(\.id), [ShippedSpot.newID])
        XCTAssertEqual(commands.filter(\.opensWithSettingsKey).map(\.id), [ShippedSpot.settingsID])
        XCTAssertEqual(commands.filter(\.opensWithNewKey).map(\.id), [ShippedSpot.newID])
    }
}
