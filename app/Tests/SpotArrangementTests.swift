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
        panel-key = "cmd+k"

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

    func testASpotKeptOutOfSearchIsReadAndKeptThroughAWrite() throws {
        let file = ConfigFile(url: try temporaryFolder().appendingPathComponent("config.toml"))
        try "[[spots]]\nid = \"icon\"\nsearch = false\n".write(to: file.url, atomically: true, encoding: .utf8)

        var arrangement = file.read().arrangement
        XCTAssertEqual(file.read().faults, [])
        XCTAssertEqual(arrangement.isFound(of: "icon"), false)
        XCTAssertNil(arrangement.isFound(of: "apps"))
        arrangement.set(size: .large, of: "icon")
        try file.write(arrangement)

        XCTAssertEqual(file.read().arrangement.isFound(of: "icon"), false)
    }

    func testTheDefaultsKeepTheIconAndTheWelcomeOutOfSearch() throws {
        let defaults = Config(text: try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("defaults.toml"), encoding: .utf8))

        XCTAssertEqual(defaults.arrangement.isFound(of: "openspot/icon"), false)
        XCTAssertEqual(defaults.arrangement.isFound(of: "openspot/welcome"), false)
        XCTAssertNil(defaults.arrangement.isFound(of: "openspot/quit"))
    }

    func testAnOldLetterIsNoFaultAndAWriteDropsIt() throws {
        let folder = try temporaryFolder()
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        try "[[spots]]\nid = \"apps\"\nletter = \"a\"\nsize = \"small\"\n".write(to: file.url, atomically: true, encoding: .utf8)

        var arrangement = file.read().arrangement
        XCTAssertEqual(file.read().faults, [])
        arrangement.set(size: .large, of: "apps")
        try file.write(arrangement)

        XCTAssertFalse(try String(contentsOf: file.url, encoding: .utf8).contains("letter"))
        XCTAssertEqual(file.read().arrangement.choices, [choice("apps", size: .large)])
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

        try file.set("panel-key", to: "cmd+k")
        try file.write(arrangement)
        try file.set("panel-key", to: "cmd+j")
        try file.write(SpotArrangement(choices: arrangement.choices.reversed()))

        let config = file.read()
        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.panelKey, Shortcut(text: "cmd+j"))
        XCTAssertEqual(config.arrangement.choices, arrangement.choices.reversed())
    }

    func testASizeStepTakesTheNextSizeSinceTheGridKeepsIt() {
        let sizes: [SpotSize] = [.small, .small]

        XCTAssertEqual(SpotGrid().nextSize(of: 0, in: sizes, among: [.small, .wide, .strip]), .wide)
    }

    func testASizeStepTurnsBackToTheFirstSize() {
        XCTAssertEqual(SpotGrid().nextSize(of: 0, in: [.strip], among: [.small, .wide, .strip]), .small)
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

    func testAKeyOfThePanelOpensTheSpotOfThePersonsChoiceOrElseOfTheDefaults() throws {
        let n = ActionKey(name: "n", isCommand: true)
        let defaults = Config(text: "[[spots]]\nid = \"new\"\nkey = \"cmd+n\"\n\n[[spots]]\nid = \"set\"\nkey = \"cmd+,\"\n").arrangement
        let mine = Config(text: "[[spots]]\nid = \"mine\"\nkey = \"cmd+n\"\n").arrangement
        let moved = Config(text: "[[spots]]\nid = \"new\"\nkey = \"cmd+j\"\n").arrangement

        XCTAssertEqual(SpotArrangement().spot(openedBy: n, over: defaults), "new")
        XCTAssertEqual(SpotArrangement().spot(openedBy: ActionKey(name: ",", isCommand: true), over: defaults), "set")
        XCTAssertEqual(mine.spot(openedBy: n, over: defaults), "mine")
        XCTAssertNil(moved.spot(openedBy: n, over: defaults))
        XCTAssertNil(SpotArrangement().spot(openedBy: ActionKey(name: "m", isCommand: true), over: defaults))
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"a\"\nkey = \"cmd+space+\"\n").faults, ["config.toml: a cannot use the key cmd+space+."])
        var config = Config()
        config.arrangement = mine
        XCTAssertTrue(config.text.contains("key = \"cmd+n\""))
    }
}
