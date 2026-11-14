import XCTest
@testable import OpenspotCore

final class ReleaseLogTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-releases-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private let mine = try! AccountKey(words: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".split(separator: " ").map(String.init))
    private let theirs = try! AccountKey.make()

    private func spot(_ script: String = "#!/bin/sh\n# title=Cups\n", extra: [SpotPackage.File] = []) throws -> SpotPackage {
        try SpotPackage(files: [
            SpotPackage.File(path: "cups.spot/cups.sh", isExecutable: true, contents: Data(script.utf8)),
            SpotPackage.File(path: "cups.spot/readme.md", isExecutable: false, contents: Data("Counts cups.\n".utf8))
        ] + extra)
    }

    private func log(of spot: SpotPackage) throws -> ReleaseLog {
        try XCTUnwrap(try spot.releaseLog(in: "cups.spot"))
    }

    private func editing(_ spot: SpotPackage, _ path: String, to text: String) throws -> SpotPackage {
        try SpotPackage(files: spot.files.map { $0.path == path ? SpotPackage.File(path: path, isExecutable: $0.isExecutable, contents: Data(text.utf8)) : $0 })
    }

    func testAFirstSignatureMakesVersionOneOfANewAddressThatNamesEveryFileButTheLog() throws {
        let signed = try spot().signed(by: mine)

        let release = try XCTUnwrap(log(of: signed).last)
        XCTAssertEqual(release.version, 1)
        XCTAssertNotNil(release.address)
        XCTAssertNil(release.previous)
        XCTAssertEqual(release.content, "Counts cups.\n")
        XCTAssertEqual(try release.manifest().sorted.map(\.path), ["cups.spot/cups.sh", "cups.spot/readme.md"])
    }

    func test_P7_aSpotWhoseFilesTheLastReleaseNamesIsSentAsItIs() throws {
        let signed = try spot().signed(by: mine)

        XCTAssertEqual(try signed.signed(by: mine), signed)
        XCTAssertEqual(try signed.signed(by: theirs), signed)
    }

    func test_P13_aChangeSignedByTheSameKeyIsTheNextVersionOfTheSameAddress() throws {
        let first = try spot().signed(by: mine)

        let second = try editing(first, "cups.spot/cups.sh", to: "#!/bin/sh\n# title=Mugs\n").signed(by: mine)

        let releases = try log(of: second).releases
        XCTAssertEqual(releases.map(\.version), [1, 2])
        XCTAssertEqual(releases[1].address, releases[0].address)
        XCTAssertEqual(releases[1].previous, releases[0].id)
    }

    func test_P13_aChangeSignedByAnotherKeyIsANewAddressThatKeepsTheLog() throws {
        let first = try spot().signed(by: mine)

        let copy = try editing(first, "cups.spot/cups.sh", to: "#!/bin/sh\n# title=Mugs\n").signed(by: theirs)

        let releases = try log(of: copy).releases
        XCTAssertEqual(releases.map(\.publicKey), [mine.publicKey, theirs.publicKey])
        XCTAssertEqual(releases[1].version, 1)
        XCTAssertNotEqual(releases[1].address, releases[0].address)
        XCTAssertEqual(releases[1].previous, releases[0].id)
    }

    func test_P12_aLogThatDoesNotMatchItsFilesIsRefused() throws {
        let signed = try spot().signed(by: mine)
        let changed = try editing(signed, "cups.spot/cups.sh", to: "#!/bin/sh\nrm -rf ~\n")
        let missing = try SpotPackage(files: signed.files.filter { $0.path != "cups.spot/readme.md" })
        let added = try SpotPackage(files: signed.files + [SpotPackage.File(path: "cups.spot/more.sh", isExecutable: true, contents: Data("x".utf8))])

        for spot in [changed, missing, added] {
            XCTAssertThrowsError(try spot.releaseLog(in: "cups.spot")) { error in
                XCTAssertEqual((error as? SpotError)?.reason, "cups.spot does not match its last release, so a file changed after it was signed.")
            }
        }
    }

    func test_P12_aLogWithABrokenLinkOrABadSignatureIsRefused() throws {
        let first = try spot().signed(by: mine)
        let second = try editing(first, "cups.spot/cups.sh", to: "#!/bin/sh\n# title=Mugs\n").signed(by: mine)
        let lines = try log(of: second).text.split(separator: "\n").map(String.init)

        XCTAssertThrowsError(try ReleaseLog(text: lines[1] + "\n")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "releases.jsonl holds a release that does not follow the one before it.")
        }
        XCTAssertThrowsError(try ReleaseLog(text: lines[0].replacingOccurrences(of: "Counts cups.", with: "Counts mugs.") + "\n")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "releases.jsonl holds a release whose signature does not match.")
        }
    }

    func testAProgramThatAPublishBuiltCanBeMissingFromTheFolderOnTheDisk() throws {
        let program = SpotPackage.File(path: "cups.spot/cups.program", isExecutable: true, contents: Data([0xCF, 0xFA]))
        let log = try log(of: spot(extra: [program]).signed(by: mine))

        XCTAssertTrue(log.names(SpotManifest(try spot().files), built: false))
        XCTAssertFalse(log.names(SpotManifest(try spot().files)))
    }

    func testTheReviewOfAReleaseSaysItsVersionOrThatAnotherKeySignedIt() throws {
        let first = try log(of: spot().signed(by: mine))
        let second = try log(of: editing(spot().signed(by: mine), "cups.spot/cups.sh", to: "#!/bin/sh\n# title=Mugs\n").signed(by: mine))
        let copy = try log(of: editing(spot().signed(by: mine), "cups.spot/cups.sh", to: "#!/bin/sh\n# title=Mugs\n").signed(by: theirs))

        XCTAssertEqual(second.review(over: nil).lines, [])
        XCTAssertEqual(second.review(over: first).lines, ["Update to version 2"])
        XCTAssertTrue(copy.review(over: first).isOtherKey)
        XCTAssertTrue(ReleaseLog(releases: []).review(over: first).isOtherKey)
    }

    func test_P7_theLogKeptInTheFolderIsTheOneTheNextSignatureFollows() throws {
        let signed = try spot().signed(by: mine)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("cups.spot"), withIntermediateDirectories: true)

        try signed.keepReleaseLog(in: folder)

        let kept = try String(contentsOf: folder.appendingPathComponent("cups.spot/releases.jsonl"), encoding: .utf8)
        XCTAssertEqual(kept, try log(of: signed).text)
    }

    func testTheStoreKeepsTheKeyInItsFileAndMakesItOnce() throws {
        let store = AccountStore.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: folder, devState: nil)
        XCTAssertNil(try store.key())

        let key = try store.keyMadeOnce()

        XCTAssertEqual(try store.keyMadeOnce(), key)
        let file = folder.appendingPathComponent("account")
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), key.words?.joined(separator: " "))
        try store.keep(try AccountKey(nsec: mine.nsec))
        XCTAssertEqual(try store.key(), mine)
    }

    func testAStoreOfAReleaseBuildUsesTheKeychain() {
        XCTAssertNil(AccountStore.standard(environment: [:], home: folder, devState: nil).file)
        XCTAssertNotNil(AccountStore.standard(environment: [:], home: folder, devState: "/repo/.temp/openspot").file)
    }
}
