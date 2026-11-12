import XCTest
@testable import OpenspotCore

final class SpotPackageTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-package-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func shared(_ text: String = "#!/bin/sh\n# title=Timer\n", extra: [SharedSpot.File] = []) throws -> SharedSpot {
        try SharedSpot(files: [SharedSpot.File(path: "tools.spot/timer.sh", isExecutable: true, contents: Data(text.utf8))] + extra)
    }

    func testAWrittenPackageIsTheSpotFolderOfItsFirstName() throws {
        let spot = try shared()
        let url = SpotPackage.url(for: "tools/timer", in: folder)

        try SpotPackage.write(spot, to: folder)

        XCTAssertEqual(url.lastPathComponent, "tools.spot")
        XCTAssertEqual(try SpotPackage(url: url).spot(), spot)
        XCTAssertEqual(SpotPackage(url: url).hash, SpotPackage.hash(of: spot, in: "tools.spot"))
    }

    func testTheHashChangesWithTheWrittenFilesOnly() throws {
        let program = SharedSpot.File(path: "tools.spot/timer.program", isExecutable: true, contents: Data([0, 1]))
        XCTAssertEqual(SpotPackage.hash(of: try shared(), in: "tools.spot"), SpotPackage.hash(of: try shared(extra: [program]), in: "tools.spot"))
        XCTAssertNotEqual(SpotPackage.hash(of: try shared(), in: "tools.spot"), SpotPackage.hash(of: try shared("#!/bin/sh\n# title=Clock\n"), in: "tools.spot"))
    }

    func testAPublishReplacesTheOldPackageWhole() throws {
        let readme = SharedSpot.File(path: "tools.spot/readme.md", isExecutable: false, contents: Data("Old.".utf8))
        try SpotPackage.write(try shared(extra: [readme]), to: folder)

        try SpotPackage.write(try shared("#!/bin/sh\n# title=Clock\n"), to: folder)

        XCTAssertEqual(try SpotPackage(url: SpotPackage.url(for: "tools", in: folder)).spot().files.map(\.path), ["tools.spot/timer.sh"])
    }

    func testAStoreWithNoPackageHasNoHash() {
        XCTAssertNil(SpotPackage(url: SpotPackage.url(for: "gone", in: folder)).hash)
    }
}
