import XCTest
@testable import OpenspotCore

final class SpotManifestTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-manifest-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(_ text: String = "#!/bin/sh\n# title=Timer\n", extra: [SpotPackage.File] = []) throws -> SpotPackage {
        try SpotPackage(files: [SpotPackage.File(path: "tools.spot/timer.sh", isExecutable: true, contents: Data(text.utf8))] + extra)
    }

    func testEqualFilesGiveAnEqualManifestAndHash() throws {
        XCTAssertEqual(try spot().manifest(of: "tools.spot"), try spot().manifest(of: "tools.spot"))
        XCTAssertEqual(try spot().manifest(of: "tools.spot").hash, try spot().manifest(of: "tools.spot").hash)
        XCTAssertNotEqual(try spot().manifest(of: "tools.spot").hash, try spot("#!/bin/sh\n# title=Clock\n").manifest(of: "tools.spot").hash)
    }

    func testAModeChangeIsAChange() throws {
        let plain = try SpotPackage(files: [SpotPackage.File(path: "tools.spot/timer.sh", isExecutable: false, contents: Data("#!/bin/sh\n# title=Timer\n".utf8))])

        XCTAssertNotEqual(plain.manifest(of: "tools.spot"), try spot().manifest(of: "tools.spot"))
    }

    func testTheWrittenFilesLeaveOutWhatAPublishBuilds() throws {
        let program = SpotPackage.File(path: "tools.spot/timer.program", isExecutable: true, contents: Data([0, 1]))
        let library = SpotPackage.File(path: "tools.spot/glass.view", isExecutable: false, contents: Data([2]))

        XCTAssertEqual(try spot(extra: [program, library]).manifest(of: "tools.spot").written, try spot().manifest(of: "tools.spot"))
    }

    func testAManifestLeavesOutTheReleaseLog() throws {
        let log = SpotPackage.File(path: "tools.spot/releases.jsonl", isExecutable: false, contents: Data("{}\n".utf8))

        XCTAssertEqual(try spot(extra: [log]).manifest(of: "tools.spot"), try spot().manifest(of: "tools.spot"))
    }

    func testAWriteReplacesTheOldSpotFolderWhole() throws {
        let readme = SpotPackage.File(path: "tools.spot/readme.md", isExecutable: false, contents: Data("Old.".utf8))
        try spot(extra: [readme]).write(to: folder)

        try spot("#!/bin/sh\n# title=Clock\n").write(to: folder)

        XCTAssertEqual(try SpotPackage(contentsOf: folder.appendingPathComponent("tools.spot")).files.map(\.path), ["tools.spot/timer.sh"])
    }
}
