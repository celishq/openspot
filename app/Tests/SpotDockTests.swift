import XCTest
@testable import OpenspotCore

final class SpotDockTests: XCTestCase {
    private func item(_ name: String) -> SpotDock.Item {
        SpotDock.Item(command: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh")))
    }

    private var dock: SpotDock {
        SpotDock(items: [item("Timer"), item("Disk"), item("Coin")])
    }

    func testTheDockShowsEachSpotByName() {
        XCTAssertEqual(dock.shown.map(\.command.name), ["Coin", "Disk", "Timer"])
    }

    func testTheSearchKeepsTheSpotsWhoseNameHoldsIt() {
        var dock = dock
        dock.query = "ti"

        XCTAssertEqual(dock.shown.map(\.command.name), ["Timer"])
    }

    func testTheSearchFindsTheWordsUnderASpotsName() {
        var dock = SpotDock(items: [SpotDock.Item(command: Spot(id: "system", name: "System", url: URL(fileURLWithPath: "/system.toml"), subtitle: "Battery, CPU"))])
        dock.query = "cpu"

        XCTAssertEqual(dock.shown.map(\.id), ["system"])
    }
}
