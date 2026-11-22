import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTomlTests: XCTestCase {
    private func folder(_ name: String, toml: String?, scripts: [String: String]) throws -> URL {
        let spots = try temporaryFolder()
        let folder = spots.appendingPathComponent("\(name).spot", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let toml { try toml.write(to: folder.appendingPathComponent("spot.toml"), atomically: false, encoding: .utf8) }
        for (file, text) in scripts { try text.writeScript(to: folder.appendingPathComponent(file)) }
        return spots
    }

    func testAFolderWithASpotTomlLoadsWithItsTitleEventsActionsAndSettings() throws {
        let toml = """
        title = "Weather"
        uses = ["network", "clipboard"]

        [actions.refresh]
        title = "Refresh"

        [settings]
        city = { type = "text", title = "City" }

        [on]
        "sheet.open" = true
        every = 300
        """
        let spots = try folder("weather", toml: toml, scripts: ["weather.sh": "#!/bin/sh\necho\n", "helper.sh": "#!/bin/sh\necho\n"])

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.spots.map(\.name), ["Weather"])
        let weather = try XCTUnwrap(scan.spots.first)
        XCTAssertEqual(weather.on?.has(.sheet), true)
        XCTAssertEqual(weather.on?.seconds, 300)
        XCTAssertEqual(weather.uses, [.network, .clipboard])
        XCTAssertEqual(weather.offers.map(\.id), ["refresh"])
        XCTAssertEqual(weather.settings.map(\.id), ["city"])
    }

    func testAnUnknownKeyKeepsTheSpotFromLoadingWithAFaultThatNamesTheKey() throws {
        let spots = try folder("cups", toml: "titel = \"Cups\"\n", scripts: ["cups.sh": "#!/bin/sh\necho\n"])

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots, [])
        XCTAssertEqual(scan.refused.map(\.file), ["cups"])
        XCTAssertTrue(scan.refused.first?.reason.contains("titel") == true)
    }

    func testACommentHeaderIsOrdinaryTextAndTheFileNameIsTheTitle() throws {
        let spots = try folder("brew", toml: nil, scripts: ["brew.sh": "#!/bin/sh\n# title=Coffee\n# on=sheet.open\necho\n"])

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots.map(\.name), ["Brew"])
        XCTAssertNil(scan.spots.first?.on)
    }

    func testALooseScriptThatOpenspotMovesIntoAFolderGetsASpotToml() throws {
        let spots = try temporaryFolder()
        try "#!/bin/sh\necho\n".writeScript(to: spots.appendingPathComponent("tea-time.sh"))

        let scan = try SpotsFolder(url: spots, wrapsLooseFiles: true).scan()

        let toml = try String(contentsOf: spots.appendingPathComponent("tea-time.spot/spot.toml"), encoding: .utf8)
        XCTAssertEqual(toml, "title = \"Tea time\"\n")
        XCTAssertEqual(scan.spots.map(\.name), ["Tea time"])
    }

    func testTheStampOfASpotChangesWithAnEditOfItsSpotToml() throws {
        let spots = try folder("cups", toml: "title = \"Cups\"\n", scripts: ["cups.sh": "#!/bin/sh\necho\n"])
        let load = KeptScan().load(SpotsFolder(url: spots))
        let spot = try XCTUnwrap(try load.result(enabled: [], disabled: [], hosted: []).spots.first)

        try "title = \"Coffee cups\"\n".write(to: spots.appendingPathComponent("cups.spot/spot.toml"), atomically: false, encoding: .utf8)

        XCTAssertNotEqual(KeptScan().load(SpotsFolder(url: spots)).stamp(of: spot), load.stamp(of: spot))
    }

    func testModeIsAnUnknownKey() throws {
        let spots = try folder("clock", toml: "mode = \"always\"\n", scripts: ["clock.sh": "#!/bin/sh\necho\n"])

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots, [])
        XCTAssertTrue(scan.refused.first?.reason.contains("unknown key in its spot.toml: mode") == true)
    }
}
