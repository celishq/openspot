import XCTest
@testable import OpenspotCore

@MainActor
final class SpotStarterTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-starter-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testEachStarterLoadsAndPassesTheCheck() async throws {
        for starter in SpotStarter.allCases {
            let place = folder.appendingPathComponent(starter.rawValue)

            let file = try starter.write(name: "Weather today", in: place)

            let faults = await SpotCheck(folder: SpotsFolder(url: place)).faults()
            XCTAssertEqual(faults, [], "\(starter)")
            let spot = try XCTUnwrap(SpotsFolder(url: place).scan().spots.first, "\(starter)")
            XCTAssertEqual(spot.id, "weather-today")
            XCTAssertEqual(spot.name, "Weather today")
            XCTAssertEqual(file.lastPathComponent, "weather-today.sh")
        }
    }

    func testEachStarterDescribesItsSpotInSpotTomlAndItsScriptHoldsNoHeader() throws {
        for starter in SpotStarter.allCases {
            let place = folder.appendingPathComponent(starter.rawValue)

            let file = try starter.write(name: "Say \"hi\"", in: place)

            let manifest = try ConfigDocument(text: String(contentsOf: file.deletingLastPathComponent().appendingPathComponent("spot.toml"), encoding: .utf8))
            let script = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            XCTAssertEqual(manifest.values["title"], .string("Say \"hi\""), "\(starter)")
            XCTAssertEqual(manifest.values["icon"], .string(starter.symbol), "\(starter)")
            XCTAssertEqual(script.first, "#!/bin/sh", "\(starter)")
            XCTAssertFalse(script.dropFirst().contains { $0.hasPrefix("#") }, "\(starter)")
        }
    }

    func testAPickOfTheListStarterReadsAKeyOfItsRow() async throws {
        _ = try SpotStarter.list.write(name: "Weather", in: folder)
        let spot = try XCTUnwrap(SpotsFolder(url: folder).scan().spots.first)
        let rows = try await spot.answer(.show, timeout: 10).items

        let picked = try await spot.answer(SpotAction(arguments: ["open", "second"]), input: rows.last?.fields, timeout: 10)

        XCTAssertEqual(rows.map(\.run), ["first", "second"])
        XCTAssertEqual(picked.toast, "You picked the row that says: Hello again")
    }

    func testANameThatAnotherSpotHasIsRefused() throws {
        _ = try SpotStarter.button.write(name: "Weather", in: folder)

        XCTAssertThrowsError(try SpotStarter.list.write(name: "weather", in: folder)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "A spot called weather already exists. Choose another name.")
        }
    }

    func testANameNeedsALetterOrADigit() {
        XCTAssertThrowsError(try SpotStarter.button.write(name: "!!", in: folder)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Use letters or digits in the name.")
        }
    }
}
