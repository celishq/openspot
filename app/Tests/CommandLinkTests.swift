import XCTest
@testable import OpenspotCore

final class CommandLinkTests: XCTestCase {
    private final class Fake: @unchecked Sendable {
        var lines: [String] = []
    }

    private var folder: URL!
    private let fake = Fake()

    private var bin: URL { folder.appendingPathComponent("bin") }
    private var target: URL { folder.appendingPathComponent("Openspot.app/Contents/Helpers/openspot") }

    private var link: CommandLink {
        let fake = fake
        return CommandLink(link: bin.appendingPathComponent("openspot"), target: target, elevated: { fake.lines.append($0) })
    }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bin.path)
        try? FileManager.default.removeItem(at: folder)
    }

    private func settings(_ link: CommandLink) -> SettingsSpot {
        SettingsSpot(file: ConfigFile(url: folder.appendingPathComponent("config.toml")), folder: folder, link: link)
    }

    func testSettingsListsTheRowOffUntilALinkPointsAtTheApp() throws {
        let off = PluginOutput(text: try settings(link).answer(["read"])).items
        XCTAssertEqual(off.map(\.run), ["panel_key", "fix_key", CommandLink.run])
        XCTAssertEqual(off.last?.title, "Use openspot in Terminal")
        XCTAssertEqual(off.last?.isOn, false)

        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: bin.appendingPathComponent("openspot"), withDestinationURL: folder)
        XCTAssertEqual(PluginOutput(text: try settings(link).answer(["read"])).items.last?.isOn, false)
    }

    func testAPickLinksTheCommandThenRemovesIt() throws {
        let on = try settings(link).answer(["open", CommandLink.run])

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: bin.appendingPathComponent("openspot").path), target.path)
        XCTAssertEqual(PluginOutput(text: on).summary?.value("toast"), "Installed openspot")

        let off = try settings(link).answer(["open", CommandLink.run])

        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("openspot").path))
        XCTAssertEqual(PluginOutput(text: off).summary?.value("toast"), "Removed openspot")
        XCTAssertEqual(fake.lines, [])
    }

    func testALinkItCannotWriteAsksForTheRightsOfAnAdministrator() throws {
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: bin.path)

        _ = try settings(link).answer(["open", CommandLink.run])

        XCTAssertEqual(fake.lines, ["/bin/mkdir -p '\(bin.path)' && /bin/ln -sfn '\(target.path)' '\(bin.path)/openspot'"])
    }
}
