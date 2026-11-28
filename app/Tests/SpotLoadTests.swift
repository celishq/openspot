import XCTest
@testable import OpenspotCore

@MainActor
final class SpotLoadTests: PanelCase {
    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        let host = FakeHost()
        self.host = host
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        for name in ["a", "b"] {
            let file = core.appendingPathComponent("\(name).spot/\(name).sh")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "#!/bin/sh\n:\n".writeScript(to: file, toml: "title = '\(name)'")
        }
        try script("own", toml: "title = 'Own'", ":")
    }

    func testASpotOfYourOwnKeepsNoUseThatOnlyASpotOfOpenspotTakes() async throws {
        try script("mine", toml: "title = 'Mine'\nuses = ['agent', 'account', 'clipboard']", ":")

        await model.reload()

        XCTAssertEqual(model.entries.first { $0.id == "mine" }?.spot.uses, [.clipboard])
    }

    func testAReloadStatsNoFileOnTheMainThread() async throws {
        let work = ScanWork()

        await ScanWork.$meter.withValue(work) {
            await model.reload()
        }

        XCTAssertGreaterThan(work.stats, 0)
        XCTAssertEqual(work.statsOnMain, 0)
        XCTAssertEqual(model.entries.map(\.id), ["own", "a", "b"])
    }

    func testAGridChangeOfOneCoreSpotParsesNoFile() async throws {
        await model.reload()
        let next = try model.files.config.change { $0.arrangement.set(isOnGrid: true, of: "a") }
        let work = ScanWork()

        ScanWork.$meter.withValue(work) {
            model.configChanged(.spots(["a"]), to: next)
        }

        XCTAssertEqual(model.entries.map(\.id).sorted(), ["a", "b", "own"])
        XCTAssertEqual(work.parses, 0)
        XCTAssertEqual(work.statsOnMain, 0)
    }

    func testAReloadKeepsTheHeaderOfASpotWhoseFilesDidNotChange() async throws {
        try model.files.config.change { $0.set(setting: ReservedSetting.icon, of: "own", to: "cup.and.saucer") }
        await model.reload()
        let header = try XCTUnwrap(model.entries.first { $0.id == "own" }).spot.header
        try script("other", toml: "title = 'Other'", ":")

        await model.reload()

        XCTAssertEqual(model.entries.map(\.id).sorted(), ["a", "b", "other", "own"])
        XCTAssertTrue(try XCTUnwrap(model.entries.first { $0.id == "own" }).spot.header === header)
    }

    func testTheVersionOfASpotIsShortAndFollowsItsStamp() {
        XCTAssertEqual(SpotLoad.version(of: [1, 2, 3]).count, 8)
        XCTAssertEqual(SpotLoad.version(of: [1, 2, 3]), SpotLoad.version(of: [1, 2, 3]))
        XCTAssertNotEqual(SpotLoad.version(of: [1, 2, 3]), SpotLoad.version(of: [1, 2, 4]))
    }
}
