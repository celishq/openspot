import XCTest
@testable import OpenspotCore

final class AccountStoreTests: XCTestCase {
    private var folder: URL!
    private var store: AccountStore!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = AccountStore.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: folder, devState: nil)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testAMadeKeyIsNotBackedUpUntilItIsMarked() throws {
        let key = try store.keyMadeOnce()
        XCTAssertFalse(try store.isBackedUp())

        try store.markBackedUp()

        XCTAssertTrue(try store.isBackedUp())
        XCTAssertEqual(try store.key(), key)
    }

    func testAKeyKeptFromItsWordsIsBackedUp() throws {
        let key = try AccountKey.make()

        try store.keep(key, isBackedUp: true)

        XCTAssertTrue(try store.isBackedUp())
        XCTAssertEqual(try store.key(), key)
    }

    func testAKeyKeptAgainLosesTheMarkOfTheOneBefore() throws {
        try store.keep(try AccountKey.make(), isBackedUp: true)

        try store.keep(try AccountKey.make())

        XCTAssertFalse(try store.isBackedUp())
    }

    func testARemovedKeyIsGone() throws {
        _ = try store.keyMadeOnce()

        try store.remove()

        XCTAssertNil(try store.key())
        XCTAssertFalse(try store.isBackedUp())
        XCTAssertNoThrow(try store.remove())
    }

    func testAFileStoreNeverSyncs() throws {
        _ = try store.keyMadeOnce()

        XCTAssertFalse(store.canSync)
        XCTAssertFalse(try store.isSyncing())
        XCTAssertThrowsError(try store.setSyncing(true)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This copy of Openspot keeps your account on this Mac only.")
        }
    }
}
