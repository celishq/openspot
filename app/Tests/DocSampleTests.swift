import XCTest
@testable import OpenspotCore

final class DocSampleTests: XCTestCase {
    private let sample = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/sample", isDirectory: true)

    func testEachSpotThatTheSampleConfigPlacesLoadsUnderThatID() throws {
        let root = try temporaryFolder()
        let spots = root.appendingPathComponent("spots", isDirectory: true)
        try FileManager.default.copyItem(at: sample, to: spots)
        try FileManager.default.moveItem(at: spots.appendingPathComponent("config.toml"), to: root.appendingPathComponent("config.toml"))

        let loaded = Set(try SpotsFolder(url: spots, wrapsLooseFiles: true).scan().files.flatMap(\.spots).map(\.id))
        let own = try Set(FileManager.default.contentsOfDirectory(atPath: sample.path).map { String($0.prefix { $0 != "." }) })
        let placed = ConfigFile(url: root.appendingPathComponent("config.toml")).read().arrangement.choices.map(\.id)
            .filter { own.contains(String($0.prefix { $0 != "/" })) }

        XCTAssertFalse(placed.isEmpty)
        for id in placed {
            XCTAssertTrue(loaded.contains(id), "\(id) is not among \(loaded.sorted())")
        }
    }
}
