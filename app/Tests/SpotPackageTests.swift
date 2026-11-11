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

    private func shared(_ text: String = "#!/bin/sh\n# title=Timer\n") throws -> SharedSpot {
        try SharedSpot(files: [SharedSpot.File(path: "timer.sh", isExecutable: true, contents: Data(text.utf8))])
    }

    func testAWrittenPackageGivesBackItsFilesListingAndHash() throws {
        let spot = try shared()
        let url = SpotPackage.url(for: "tools/timer", in: folder)

        let package = try SpotPackage.write(spot, title: "Timer \"5\"", description: "Counts down", readme: "Counts down.", preview: "row=a\ntitle=Sample\n", to: url)

        XCTAssertEqual(url.lastPathComponent, "tools-timer.spot")
        XCTAssertEqual(package.hash, SpotPackage.hash(of: spot))
        XCTAssertEqual(package.title, "Timer \"5\"")
        XCTAssertEqual(try package.spot(), spot)
        XCTAssertEqual(package.listing, SpotListing(description: "Counts down", readme: "Counts down.", preview: [SpotItem(title: "Sample", run: "a")]))
    }

    func testTheHashChangesWithTheFilesOnly() throws {
        XCTAssertEqual(SpotPackage.hash(of: try shared()), SpotPackage.hash(of: try shared()))
        XCTAssertNotEqual(SpotPackage.hash(of: try shared()), SpotPackage.hash(of: try shared("#!/bin/sh\n# title=Clock\n")))
    }

    func testAPublishReplacesTheOldPackage() throws {
        let url = SpotPackage.url(for: "timer", in: folder)
        _ = try SpotPackage.write(try shared(), title: "Timer", description: nil, readme: "Old.", preview: nil, to: url)

        let package = try SpotPackage.write(try shared("#!/bin/sh\n# title=Clock\n"), title: "Clock", description: nil, readme: "New.", preview: nil, to: url)

        XCTAssertEqual(package.title, "Clock")
        XCTAssertEqual(package.listing.readme, "New.")
        XCTAssertEqual(package.listing.preview, [])
    }
}
