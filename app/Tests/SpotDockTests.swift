import XCTest
@testable import OpenspotCore

final class SpotDockTests: XCTestCase {
    private func item(_ name: String, _ place: SpotDock.Place) -> SpotDock.Item {
        SpotDock.Item(command: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh")), place: place)
    }

    private var dock: SpotDock {
        SpotDock(items: [item("Timer", .off), item("Windows", .search), item("Weather", .fix), item("Disk", .search), item("Coin", .off)])
    }

    func testAllShowsEachPlaceInTurnAndEachSpotByName() {
        XCTAssertEqual(dock.shown.map(\.command.name), ["Disk", "Windows", "Coin", "Timer", "Weather"])
    }

    func testATabShowsTheSpotsOfItsPlace() {
        var dock = dock
        dock.tab = .off

        XCTAssertEqual(dock.shown.map(\.command.name), ["Coin", "Timer"])
        XCTAssertEqual(SpotDock.Tab.allCases.map { dock.count(of: $0) }, [5, 2, 2, 1])
    }

    func testTheSearchKeepsTheSpotsWhoseNameHoldsIt() {
        var dock = dock
        dock.query = "ti"

        XCTAssertEqual(dock.shown.map(\.command.name), ["Timer"])
        XCTAssertEqual(dock.count(of: .search), 0)
    }
}
