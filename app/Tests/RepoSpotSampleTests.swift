import XCTest
@testable import OpenspotCore

@MainActor
final class RepoSpotSampleTests: XCTestCase {
    private let runs = SpotRuns()

    private var folders: [URL] {
        let root = Repo.root
        return ["store", "examples"].map { root.appendingPathComponent($0) }
    }

    override func tearDown() async throws {
        runs.quit()
    }

    func testEachExampleHasAReadme() throws {
        let spots = try folders.flatMap { try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }.filter { $0.pathExtension == "spot" }
        let missing = spots.filter { !FileManager.default.fileExists(atPath: $0.appendingPathComponent("readme.md").path) }.map(\.lastPathComponent)

        XCTAssertFalse(spots.isEmpty)
        XCTAssertEqual(missing.sorted(), [])
    }

    func testEachKeptSampleIsWhatItsScriptPrints() async throws {
        let root = folders[0].deletingLastPathComponent()
        let spots = try folders.flatMap { try SpotsFolder(url: $0).scan().files.compactMap(\.spots.first) }
        let sampled = spots.filter { $0.sampled != nil }
        XCTAssertFalse(sampled.isEmpty)

        for spot in sampled {
            let script = try XCTUnwrap(spot.sample).path.replacingOccurrences(of: root.path + "/", with: "")
            let kept = SpotSample.text(beside: spot.url)
            let printed = try await runs.answer(of: try XCTUnwrap(spot.sampled), ScriptEntry.show.name, limit: 10)
            XCTAssertFalse(printed.contains(root.path), "\(script) names a file of the repo, which a copy of the spot does not have.")
            XCTAssertEqual(try? String(contentsOf: kept, encoding: .utf8), printed, "Run `sh \(script) > \(script.replacingOccurrences(of: SpotSample.scriptName, with: SpotSample.textName))`.")
        }
    }
}
