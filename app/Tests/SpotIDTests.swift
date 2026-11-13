import XCTest
@testable import OpenspotCore

final class SpotIDTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-id-\(UUID().uuidString)")
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"))
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("home.spot/lights.sh"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testEachIDThatAScanGivesFindsItsFileAgain() throws {
        let spots = try SpotsFolder(url: folder).scan().spots

        XCTAssertEqual(spots.map(\.id).sorted(), ["home/lights", "weather"])
        for spot in spots {
            let id = SpotID(spot.id)
            XCTAssertEqual(id, SpotID(file: spot.url))
            XCTAssertEqual(id.file(in: folder)?.lastPathComponent, spot.url.lastPathComponent)
            XCTAssertEqual(id.description, spot.id)
        }
    }

    func testAnIDNamesItsSpotFolderAndThePlaceOfItsScript() {
        let lights = SpotID("home/lights")

        XCTAssertEqual(lights.folderName, "home.spot")
        XCTAssertEqual(lights.file(in: folder, extension: "js").path, folder.appendingPathComponent("home.spot/lights.js").path)
        XCTAssertEqual(SpotID("weather").file(in: folder, extension: "sh").path, folder.appendingPathComponent("weather.spot/weather.sh").path)
        XCTAssertNil(SpotID("home/gone").file(in: folder))
    }

    func testScriptsOfOneSpotFolderAreOneUnit() {
        XCTAssertTrue(SpotID("home/lights").isSameFolder(as: SpotID("home")))
        XCTAssertTrue(SpotID(path: "home.spot/lights.sh").isSameFolder(as: SpotID("home/fan")))
        XCTAssertFalse(SpotID("home").isSameFolder(as: SpotID("homes")))
    }

    func testAFolderOfTheSameNameIsNoScriptThatAWidgetPlaces() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("dash.spot/cpu"), withIntermediateDirectories: true)
        try "#!/bin/sh\n# on=clock.5\n".writeScript(to: folder.appendingPathComponent("cpu.spot/cpu.sh"))
        try "#!/bin/sh\n# title=Dash\n# grid.strip=cpu cpu\n".writeScript(to: folder.appendingPathComponent("dash.spot/dash.sh"))

        let dash = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first { $0.id == "dash" })

        XCTAssertEqual(dash.places, ["cpu"])
    }

    func testAWidgetPlacesAScriptOfItsOwnSpotFolderByItsName() throws {
        try "#!/bin/sh\n# on=clock.5\n".writeScript(to: folder.appendingPathComponent("board.spot/cpu.sh"))
        try "#!/bin/sh\n# title=Desk\n# grid.strip=cpu cpu\n".writeScript(to: folder.appendingPathComponent("board.spot/board.sh"))

        let board = try XCTUnwrap(try SpotsFolder(url: folder).scan().spots.first { $0.id == "board" })

        XCTAssertEqual(board.places, ["board/cpu"])
    }
}
