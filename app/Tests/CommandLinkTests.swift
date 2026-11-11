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

    func testItIsOffUntilALinkPointsAtTheApp() throws {
        XCTAssertFalse(link.isOn)

        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: bin.appendingPathComponent("openspot"), withDestinationURL: folder)
        XCTAssertFalse(link.isOn)
    }

    func testSetLinksTheCommandThenRemovesIt() throws {
        try link.set(true)
        try link.set(true)

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: bin.appendingPathComponent("openspot").path), target.path)
        XCTAssertTrue(link.isOn)

        try link.set(false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("openspot").path))
        XCTAssertEqual(fake.lines, [])
    }

    func testALinkItCannotWriteAsksForTheRightsOfAnAdministrator() throws {
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: bin.path)

        try link.set(true)

        XCTAssertEqual(fake.lines, ["/bin/mkdir -p '\(bin.path)' && /bin/ln -sfn '\(target.path)' '\(bin.path)/openspot'"])
    }
}
