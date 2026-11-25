import XCTest
@testable import OpenspotCore

final class SpotVersionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: clock.appendingPathComponent("clock.sh"), toml: "title = 'Clock'")
        try touch(clock.appendingPathComponent("spot.toml"), at: "2031-11-25T10:31:40Z")
    }

    private var clock: URL { root.appendingPathComponent("clock.spot", isDirectory: true) }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }

    private func touch(_ file: URL, at text: String) throws {
        try FileManager.default.setAttributes([.modificationDate: try date(text)], ofItemAtPath: file.path)
    }

    private func write(_ text: String, to path: String) throws {
        let file = clock.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
        try touch(file, at: "2026-11-20T09:00:00Z")
    }

    func testAVersionIsTheMinuteOfItsNewestFileThenAShortHashOfItsFiles() throws {
        let version = try SpotVersion(of: clock)

        XCTAssertTrue(version.text.hasPrefix("2031-11-25T10:31Z-"), version.text)
        XCTAssertEqual(version.hash.count, 7)
        XCTAssertEqual(SpotVersion(text: version.text), version)
    }

    func testVersionsSortByTime() throws {
        let early = try XCTUnwrap(SpotVersion(text: "2026-11-03T08:00Z-fffffff"))
        let late = try XCTUnwrap(SpotVersion(text: "2026-11-25T10:31Z-0000000"))

        XCTAssertLessThan(early, late)
        XCTAssertTrue(late.isNewer(than: early))
        XCTAssertFalse(early.isNewer(than: late))
        XCTAssertFalse(late.isNewer(than: late))
    }

    func testTheHashLeavesOutWhatAShareLeavesOut() throws {
        let before = try SpotVersion(of: clock).hash

        try write("x", to: ".DS_Store")
        try write("x", to: "tests/run.sh")
        try write("x", to: "clock.0123.program")

        XCTAssertEqual(try SpotVersion(of: clock).hash, before)
        try write("more", to: "readme.md")
        XCTAssertNotEqual(try SpotVersion(of: clock).hash, before)
    }

    func testACopyUnderAnotherIDHasTheHashOfItsSource() throws {
        let other = root.appendingPathComponent("clock-2.spot", isDirectory: true)
        try FileManager.default.copyItem(at: clock, to: other)
        try FileManager.default.moveItem(at: other.appendingPathComponent("clock.sh"), to: other.appendingPathComponent("clock-2.sh"))

        XCTAssertEqual(try SpotVersion.hash(of: other), try SpotVersion(of: clock).hash)
    }

    func testASignedSpotTakesTheDateOfItsLastRelease() throws {
        let files = [SpotPackage.File(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]
        let signed = try SpotPackage(files: files).signed(by: AccountKey.make(), at: try date("2026-11-03T12:00:00Z"))
        try signed.write(to: root)

        XCTAssertTrue(try SpotVersion(of: root.appendingPathComponent("cups.spot")).text.hasPrefix("2026-11-03T12:00Z-"))
    }

    func testThePersonReadsAVersionAsADay() throws {
        let version = try XCTUnwrap(SpotVersion(text: "2026-11-03T12:00Z-a1b2c3d"))

        XCTAssertEqual(version.day(now: try date("2026-11-25T12:00:00Z")), "3 Nov")
        XCTAssertEqual(version.day(now: try date("2027-01-02T12:00:00Z")), "3 Nov 2026")
    }
}
