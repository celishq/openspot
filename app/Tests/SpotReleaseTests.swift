import XCTest
@testable import OpenspotCore

final class SpotReleaseTests: XCTestCase {
    /// An event that `celis-nostr` signed with the key of the fixture phrase, with quotes, a tab, a new line, a slash, a
    /// backslash and emoji in its content.
    private let signedByCelis = #"{"id":"b9a992d1d0ed70c5712d5aff0ef80010f6427492613cfaf5ce3a5e64fd0efff6","pubkey":"b39f080e7ee987d882b14592c63889b20541057278e8d74182f6ed14a12265b1","created_at":1762900000,"kind":30063,"tags":[["d","4f6f2c1e9a8b4d2c8e7f6a5b4c3d2e1f@1"],["file","cups.spot/cups.sh","9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08","4","755"]],"content":"Counts \"cups\"\n\tof tea/coffee \\ with ☕ and 🍵","sig":"158159a01674c52b945974981ce54b00dd50f61865bf5c8c6bbc80505110dc90bbb9000ce898031db5a04f45090730b44f96d38aaea53e1f1b47058ee5032e55"}"#

    private func key() throws -> AccountKey {
        try AccountKey(words: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".split(separator: " ").map(String.init))
    }

    private let files = [
        SharedSpot.File(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("test".utf8)),
        SharedSpot.File(path: "cups.spot/readme.md", isExecutable: false, contents: Data("Counts cups.\n".utf8))
    ]

    func testAnEventThatCelisSignedIsAuthenticAndReadsItsParts() throws {
        let release = try SpotRelease(line: signedByCelis)

        XCTAssertTrue(release.isAuthentic)
        XCTAssertEqual(release.address, "4f6f2c1e9a8b4d2c8e7f6a5b4c3d2e1f")
        XCTAssertEqual(release.version, 1)
        XCTAssertEqual(release.publicKey, try key().publicKey)
        XCTAssertEqual(try release.files(), [SpotRelease.File(path: "cups.spot/cups.sh", sha256: "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08", size: 4, isExecutable: true)])
        XCTAssertEqual(release.line, signedByCelis)
    }

    func testOneChangedByteInTheContentATagOrTheSignatureFailsTheCheck() throws {
        let changes = [
            ("of tea/coffee", "of tea/cocoa"),
            ("cups.spot/cups.sh", "cups.spot/mugs.sh"),
            ("\"sig\":\"1581", "\"sig\":\"1582")
        ]
        for (old, new) in changes {
            XCTAssertFalse(try SpotRelease(line: signedByCelis.replacingOccurrences(of: old, with: new)).isAuthentic, new)
        }
    }

    func testASignedReleaseNamesEachFileItsAddressItsVersionAndTheOneBefore() throws {
        let release = try SpotRelease.sign(files, address: "a1", version: 2, previous: "ff00", readme: "Counts cups.\n", by: key(), at: Date(timeIntervalSince1970: 100))

        XCTAssertTrue(release.isAuthentic)
        XCTAssertEqual(release.kind, 30063)
        XCTAssertEqual(release.createdAt, 100)
        XCTAssertEqual(release.address, "a1")
        XCTAssertEqual(release.version, 2)
        XCTAssertEqual(release.previous, "ff00")
        XCTAssertEqual(try release.files().map(\.path), ["cups.spot/cups.sh", "cups.spot/readme.md"])
        XCTAssertEqual(try release.files().map(\.isExecutable), [true, false])
        XCTAssertEqual(try SpotRelease(line: release.line), release)
    }

    func testAFirstReleaseNamesNoneBefore() throws {
        XCTAssertNil(try SpotRelease.sign(files, address: "a1", version: 1, previous: nil, readme: "", by: key()).previous)
    }

    func testALineThatIsNoEventIsRefused() {
        XCTAssertThrowsError(try SpotRelease(line: "{}")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "A line of releases.jsonl is not a nostr event.")
        }
    }
}
