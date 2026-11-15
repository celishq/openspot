import XCTest
@testable import OpenspotCore

@MainActor
final class SpotSampleTests: XCTestCase {
    private var folder: URL!
    private let runs = SpotRuns()

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sample-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private var core: URL { folder.appendingPathComponent("core") }
    private var spots: URL { folder.appendingPathComponent("spots") }
    private var store: URL { folder.appendingPathComponent("store") }

    private func spot(_ header: String, body: String = "", named name: String = "timer") throws -> Spot {
        let url = spots.spotFile(name)
        try "#!/bin/sh\n\(header)\n\(body)\n".writeScript(to: url)
        return try XCTUnwrap(try SpotFile(file: url, id: name)?.spots.first)
    }

    private func output(of id: String) async throws -> SpotOutput? {
        let items = SpotStore(url: store, folder: SpotsFolder(url: spots, core: core), arrangement: SpotArrangement()).items(publications: false)
        return await SpotSample.output(of: try XCTUnwrap(items.first { $0.id == id }), runs: runs)
    }

    func testASampleScriptBesideASpotGivesItASampleAndIsNoSpotOfItsOwn() throws {
        let timer = try spot("# title=Timer")
        let sample = SpotSample.script(beside: timer.url)
        try "#!/bin/sh\nprintf 'row=a\\ntitle=Sample\\n'\n".writeScript(to: sample)

        XCTAssertEqual(try spot("# title=Timer").sample, sample)
        XCTAssertNil(try spot("# title=Plain", named: "plain").sample)
        XCTAssertNil(try SpotFile(file: sample, id: "timer/sample"))
    }

    func testAScriptNamedSampleInItsOwnFolderIsASpot() throws {
        let spot = try self.spot("# title=Sample", named: "sample")

        XCTAssertEqual(spot.name, "Sample")
        XCTAssertNil(spot.sample)
    }

    func testTheCaptureRunsTheSampleScriptAndKeepsItsTextBesideTheSpot() async throws {
        try "#!/bin/sh\nprintf 'row=a\\ntitle=Sample\\n'\n".writeScript(to: SpotSample.script(beside: spots.spotFile("timer")))
        let spot = try self.spot("# title=Timer", body: "printf 'row=a\\ntitle=Real\\n'")

        try await SpotSample.capture(of: spot, runs: runs)

        let sample = try String(contentsOf: SpotSample.text(beside: spot.url), encoding: .utf8)
        XCTAssertEqual(SpotOutput(text: sample).items.map(\.title), ["Sample"])
    }

    func testTheSampleOfASpotIsWhatItsSampleScriptPrintsAndNoneWithoutOne() async throws {
        try "#!/bin/sh\nprintf 'row=r\\ntitle=Real row\\n'\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try "#!/bin/sh\nprintf 'row=s\\ntitle=Sample row\\n'\n".writeScript(to: core.appendingPathComponent("timer.spot/sample.sh"))
        try "#!/bin/sh\nprintf 'title=Real row\\n'\n".writeScript(to: core.appendingPathComponent("coin.spot/coin.sh"))

        let sample = try await output(of: "timer")
        let none = try await output(of: "coin")

        XCTAssertEqual(sample?.items.map(\.title), ["Sample row"])
        XCTAssertNil(none)
    }

    func testASpotWithOnlyAKeptSampleShowsIt() async throws {
        try "#!/bin/sh\nprintf 'title=Real row\\n'\n".writeScript(to: core.appendingPathComponent("coin.spot/coin.sh"))
        try "row=s\ntitle=Kept\n".write(to: core.appendingPathComponent("coin.spot/sample.txt"), atomically: true, encoding: .utf8)

        let sample = try await output(of: "coin")

        XCTAssertEqual(sample?.items.map(\.title), ["Kept"])
    }

    func testASharedSpotShowsItsKeptSampleAndRunsNoScript() async throws {
        let shared = store.appendingPathComponent("shared.spot")
        try "#!/bin/sh\n# title=Shared\n".writeScript(to: shared.appendingPathComponent("shared.sh"))
        try "#!/bin/sh\nprintf 'row=s\\ntitle=Ran\\n'\n".writeScript(to: shared.appendingPathComponent("sample.sh"))
        try "row=s\ntitle=Kept\n".write(to: shared.appendingPathComponent("sample.txt"), atomically: true, encoding: .utf8)

        let sample = try await output(of: "shared")

        XCTAssertEqual(sample?.items.map(\.title), ["Kept"])
    }
}
