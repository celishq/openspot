import XCTest
@testable import OpenspotCore

/// Proves which folders the watch of the spots and the config listens to, and which changed paths it reports.
final class SpotsWatchPathsTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("openspot-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("config/spots"), withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func real(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path.replacingOccurrences(of: "/var/", with: "/private/var/", options: .anchored)
    }

    func testAConfigThatIsALinkIsWatchedInTheFolderOfItsFile() throws {
        let dotfiles = folder.appendingPathComponent("dotfiles")
        try FileManager.default.createDirectory(at: dotfiles, withIntermediateDirectories: true)
        try "".write(to: dotfiles.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let config = folder.appendingPathComponent("config/config.toml")
        try FileManager.default.createSymbolicLink(at: config, withDestinationURL: dotfiles.appendingPathComponent("config.toml"))

        let paths = SpotsWatchPaths(folder: folder.appendingPathComponent("config/spots"), config: config)

        XCTAssertTrue(paths.roots.contains(real(dotfiles)))
        XCTAssertTrue(paths.reports(real(dotfiles) + "/config.toml"))
    }

    func testAWriteOfTheLogsBesideTheSpotsIsNotReported() {
        let paths = SpotsWatchPaths(folder: folder.appendingPathComponent("config/spots"), config: folder.appendingPathComponent("config/config.toml"))
        let config = real(folder.appendingPathComponent("config"))

        XCTAssertFalse(paths.reports(config + "/logs/apps.log"))
        XCTAssertFalse(paths.reports(config + "/stats/2026-11-13"))
        XCTAssertTrue(paths.reports(config + "/config.toml"))
        XCTAssertTrue(paths.reports(config + "/spots/new.spot/new.sh"))
    }
}
