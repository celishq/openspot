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

    /// Two notes on the network since 2022, signed by other clients, from celis-nostr's `note/tests.rs`. The second has tags
    /// and a content full of quotes and slashes, which the id depends on.
    private let wild = [
        #"{"kind":1,"id":"dc90c95f09947507c1044e8f48bcf6350aa6bff1507dd4acfc755b9239b5c962","pubkey":"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d","created_at":1644271588,"tags":[],"content":"now that https://blueskyweb.org/blog/2-7-2022-overview was announced we can stop working on nostr?","sig":"230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"}"#,
        #"{"kind":3,"id":"9e662bdd7d8abc40b5b15ee1ff5e9320efc87e9274d8d440c58e6eed2dddfbe2","pubkey":"373ebe3d45ec91977296a178d9f19f326c70631d2a1b0bbba5c5ecc2eb53b9e7","created_at":1644844224,"tags":[["p","3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"],["p","75fc5ac2487363293bd27fb0d14fb966477d0f1dbc6361d37806a6a740eda91e"],["p","46d0dfd3a724a302ca9175163bdf788f3606b3fd1bb12d5fe055d1e418cb60ea"]],"content":"{\"wss://nostr-pub.wellorder.net\":{\"read\":true,\"write\":true},\"wss://nostr.bitcoiner.social\":{\"read\":false,\"write\":true},\"wss://expensive-relay.fiatjaf.com\":{\"read\":true,\"write\":true},\"wss://relayer.fiatjaf.com\":{\"read\":true,\"write\":true},\"wss://relay.bitid.nz\":{\"read\":true,\"write\":true},\"wss://nostr.rocks\":{\"read\":true,\"write\":true}}","sig":"811355d3484d375df47581cb5d66bed05002c2978894098304f20b595e571b7e01b2efd906c5650080ffe49cf1c62b36715698e9d88b9e8be43029a2f3fa66be"}"#
    ]

    func testNotesThatOtherClientsSignedCheckHere() throws {
        for line in wild {
            XCTAssertTrue(try SpotRelease(line: line).isAuthentic, line)
        }
    }

    func testAnEditWhoseIdIsComputedAgainStillFails() throws {
        let note = try SpotRelease(line: wild[0])
        let content = "something else"
        let id = AccountKey.hex(SpotRelease.digest(publicKey: note.publicKey, createdAt: note.createdAt, kind: note.kind, tags: note.tags, content: content))

        let edited = SpotRelease(id: id, publicKey: note.publicKey, createdAt: note.createdAt, kind: note.kind, tags: note.tags, content: content, signature: note.signature)

        XCTAssertFalse(edited.isAuthentic)
    }

    func testALineThatIsNoEventIsRefused() {
        XCTAssertThrowsError(try SpotRelease(line: "{}")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "A line of releases.jsonl is not a nostr event.")
        }
    }
}
