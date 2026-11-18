import XCTest
@testable import OpenspotCore

final class SpotDigestTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-digest-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(_ text: String = "#!/bin/sh\necho Timer\n", extra: [SpotPackage.File] = []) throws -> SpotPackage {
        try SpotPackage(files: [SpotPackage.File(path: "tools.spot/timer.sh", isExecutable: true, contents: Data(text.utf8))] + extra)
    }

    func testEqualFilesGiveAnEqualDigestAndHash() throws {
        XCTAssertEqual(try spot().digest(of: "tools.spot"), try spot().digest(of: "tools.spot"))
        XCTAssertEqual(try spot().digest(of: "tools.spot").hash, try spot().digest(of: "tools.spot").hash)
        XCTAssertNotEqual(try spot().digest(of: "tools.spot").hash, try spot("#!/bin/sh\necho Clock\n").digest(of: "tools.spot").hash)
    }

    func testAModeChangeIsAChange() throws {
        let plain = try SpotPackage(files: [SpotPackage.File(path: "tools.spot/timer.sh", isExecutable: false, contents: Data("#!/bin/sh\necho Timer\n".utf8))])

        XCTAssertNotEqual(plain.digest(of: "tools.spot"), try spot().digest(of: "tools.spot"))
    }

    func testTheWrittenFilesLeaveOutWhatAPublishBuilds() throws {
        let program = SpotPackage.File(path: "tools.spot/timer.program", isExecutable: true, contents: Data([0, 1]))
        let library = SpotPackage.File(path: "tools.spot/glass.view", isExecutable: false, contents: Data([2]))

        XCTAssertEqual(try spot(extra: [program, library]).digest(of: "tools.spot").written, try spot().digest(of: "tools.spot"))
    }

    func testADigestLeavesOutTheReleaseLog() throws {
        let log = SpotPackage.File(path: "tools.spot/releases.jsonl", isExecutable: false, contents: Data("{}\n".utf8))

        XCTAssertEqual(try spot(extra: [log]).digest(of: "tools.spot"), try spot().digest(of: "tools.spot"))
    }

    func testAWriteReplacesTheOldSpotFolderWhole() throws {
        let readme = SpotPackage.File(path: "tools.spot/readme.md", isExecutable: false, contents: Data("Old.".utf8))
        try spot(extra: [readme]).write(to: folder)

        try spot("#!/bin/sh\necho Clock\n").write(to: folder)

        XCTAssertEqual(try SpotPackage(contentsOf: folder.appendingPathComponent("tools.spot")).files.map(\.path), ["tools.spot/timer.sh"])
    }
}
