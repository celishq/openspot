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

    func testAMoveStepSkipsEachPlaceThatLeavesTheSpotWhereItIs() {
        let sizes: [SpotSize] = [.square, .small, .small, .wide, .small]

        XCTAssertEqual(SpotGrid().nextPlace(of: 0, in: sizes, step: 1), 1)
        XCTAssertEqual(SpotGrid().nextPlace(of: 1, in: [.small, .square, .small, .small, .square], step: 1), 4)
        XCTAssertNil(SpotGrid().nextPlace(of: 1, in: [.small, .square, .small, .small], step: 1))
    }

    func testAMoveStepFindsNoPlaceAtTheEndOfTheGrid() {
        XCTAssertNil(SpotGrid().nextPlace(of: 1, in: [.wide, .wide], step: 1))
        XCTAssertNil(SpotGrid().nextPlace(of: 0, in: [.wide, .wide], step: -1))
    }

    func testASpotOffersTheSizesItCanTake() {
        let url = URL(fileURLWithPath: "/bin/true")

        XCTAssertEqual(Spot(id: "a", name: "A", url: url).sizes.count, 5)
        XCTAssertEqual(Spot(id: "w", name: "W", url: url, kind: .widget).sizes, [])
        let updates = ShippedSpot.commands(folder: url, guide: url, app: "", update: UpdateSpot(version: "1", runningWork: { 0 }, check: {}, restart: {}))
        XCTAssertFalse(updates[0].sizes.contains(.small))
    }
}
