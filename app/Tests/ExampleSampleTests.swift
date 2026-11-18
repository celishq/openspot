import XCTest
@testable import OpenspotCore

@MainActor
final class ExampleSampleTests: XCTestCase {
    private let runs = SpotRuns()

    private var examples: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
    }

    override func tearDown() async throws {
        runs.quit()
    }

    func testEachExampleHasAReadme() throws {
        let folders = try FileManager.default.contentsOfDirectory(at: examples, includingPropertiesForKeys: nil).filter { $0.pathExtension == "spot" }
        let missing = folders.filter { !FileManager.default.fileExists(atPath: $0.appendingPathComponent("readme.md").path) }.map(\.lastPathComponent)

        XCTAssertFalse(folders.isEmpty)
        XCTAssertEqual(missing.sorted(), [])
    }

    func testEachKeptSampleIsWhatItsScriptPrints() async throws {
        let spots = try SpotsFolder(url: examples).scan().files.compactMap(\.spots.first)
        let sampled = spots.filter { $0.sampled != nil }
        XCTAssertFalse(sampled.isEmpty)

        for spot in sampled {
            let script = try XCTUnwrap(spot.sample).path.replacingOccurrences(of: examples.deletingLastPathComponent().path + "/", with: "")
            let kept = SpotSample.text(beside: spot.url)
            let printed = try await runs.answer(of: try XCTUnwrap(spot.sampled), .show, limit: 10)
            XCTAssertFalse(printed.contains(examples.path), "\(script) names a file of the repo, which a copy of the spot does not have.")
            XCTAssertEqual(try? String(contentsOf: kept, encoding: .utf8), printed, "Run `sh \(script) > \(script.replacingOccurrences(of: SpotSample.scriptName, with: SpotSample.textName))`.")
        }
    }
}
