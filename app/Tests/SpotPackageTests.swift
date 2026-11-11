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

    /// A place for a zip in a folder of its own, as a share writes it, apart from the store.
    private func sent(_ name: String) throws -> URL {
        let out = folder.appendingPathComponent("sent", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        return out.appendingPathComponent(name)
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

    func testAZippedPackageOpensWithItsFilesAndListing() throws {
        let spot = try shared()
        let package = try SpotPackage.write(spot, title: "Timer", description: "Counts down", readme: "Counts down.", preview: "row=a\ntitle=Sample\n", to: SpotPackage.url(for: "timer", in: folder))
        let zip = try sent("Timer.spot")

        try package.zip(to: zip)
        let opened = try SpotPackage.open(at: zip)

        XCTAssertEqual(opened.spot, spot)
        XCTAssertEqual(opened.readme, "Counts down.")
        XCTAssertEqual(opened.preview, "row=a\ntitle=Sample\n")
        XCTAssertEqual(opened.description, "Counts down")
    }

    func testAPackageFolderAndAFileOfTheFirstFormatOpenToo() throws {
        let spot = try shared()
        let package = try SpotPackage.write(spot, title: "Timer", description: nil, readme: "Counts down.", preview: nil, to: SpotPackage.url(for: "timer", in: folder))
        let old = folder.appendingPathComponent("Old.spot")
        try spot.data.write(to: old)

        XCTAssertEqual(try SpotPackage.open(at: package.url).readme, "Counts down.")
        XCTAssertEqual(try SpotPackage.open(at: old).spot, spot)
        XCTAssertNil(try SpotPackage.open(at: old).readme)
    }

    func testAZipWithALinkIsRefused() throws {
        let package = try SpotPackage.write(try shared(), title: "Timer", description: nil, readme: "Counts down.", preview: nil, to: SpotPackage.url(for: "timer", in: folder))
        try FileManager.default.createSymbolicLink(atPath: package.url.appendingPathComponent("files/secret").path, withDestinationPath: "/etc/hosts")
        let zip = try sent("Timer.spot")
        try package.zip(to: zip)

        XCTAssertThrowsError(try SpotPackage.open(at: zip))
    }

    func testAZipOverTheLimitIsRefusedBeforeItUnpacks() throws {
        let package = try SpotPackage.write(try shared(), title: "Timer", description: nil, readme: String(repeating: "a", count: 10_000), preview: nil, to: SpotPackage.url(for: "timer", in: folder))
        let zip = try sent("Timer.spot")
        try package.zip(to: zip)

        XCTAssertThrowsError(try SpotPackage.open(at: zip, limit: 5_000))
        XCTAssertNoThrow(try SpotPackage.open(at: zip))
    }

    func testAnEntryThatLeavesTheFolderIsUnsafe() {
        XCTAssertTrue(SpotPackage.isSafe(entry: "timer.spot/files/timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "../timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "timer.spot/../../timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "/etc/hosts"))
    }
}
