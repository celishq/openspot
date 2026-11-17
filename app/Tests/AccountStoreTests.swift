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

    func testThePublicKeyIsReadWithoutTheRecordOnceKeptAndGoesWithASignOut() throws {
        let key = try store.keyMadeOnce()

        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("account.pub"), encoding: .utf8), key.publicKey)
        XCTAssertEqual(store.publicKey(), key.publicKey)
        try store.remove()
        XCTAssertNil(store.publicKey())
    }

    func testAMadeKeyIsNotBackedUpUntilItIsMarked() throws {
        let key = try store.keyMadeOnce()
        XCTAssertFalse(try store.record()?.isBackedUp == true)

        try store.markBackedUp()

        XCTAssertTrue(try store.record()?.isBackedUp == true)
        XCTAssertEqual(try store.key(), key)
    }

    func testAMadeKeyKeepsItsHandleAndTheDayItWasMadeThroughABackup() throws {
        _ = try store.keyMadeOnce(handle: "tony", on: Date(timeIntervalSince1970: 1_794_700_800))

        try store.markBackedUp()

        XCTAssertEqual(try store.record()?.handle, "tony")
        XCTAssertEqual(try store.record()?.since, "2026-11-15")
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testAKeyKeptFromItsWordsHasNoHandleNorDay() throws {
        try store.keep(try AccountKey.make(), isBackedUp: true)

        XCTAssertNil(try store.record()?.handle)
        XCTAssertNil(try store.record()?.since)
    }

    func testAKeyKeptFromItsWordsIsBackedUp() throws {
        let key = try AccountKey.make()

        try store.keep(key, isBackedUp: true)

        XCTAssertTrue(try store.record()?.isBackedUp == true)
        XCTAssertEqual(try store.key(), key)
    }

    func testAKeyKeptAgainLosesTheMarkOfTheOneBefore() throws {
        try store.keep(try AccountKey.make(), isBackedUp: true)

        try store.keep(try AccountKey.make())

        XCTAssertFalse(try store.record()?.isBackedUp == true)
    }

    func testARemovedKeyIsGone() throws {
        _ = try store.keyMadeOnce()

        try store.remove()

        XCTAssertNil(try store.key())
        XCTAssertFalse(try store.record()?.isBackedUp == true)
        XCTAssertNoThrow(try store.remove())
    }

    func testAFileStoreNeverSyncs() throws {
        _ = try store.keyMadeOnce()

        XCTAssertFalse(store.canSync())
        XCTAssertFalse(try store.isSyncing())
        XCTAssertThrowsError(try store.setSyncing(true)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This copy of Openspot keeps your account on this Mac only.")
        }
    }

    func testThePlacesOfATestKeepTheKeyInAFolderOfTheirOwn() {
        let one = AppPlaces.test()
        let two = AppPlaces.test(["OPENSPOT_SPOTS": "/none"])

        XCTAssertNotNil(one.account.file)
        XCTAssertNotNil(two.account.file)
        XCTAssertNotEqual(one.account.file, two.account.file)
        XCTAssertNotEqual(one.home, two.home)
    }

    func testARecordMadeTheOldWayReadsAsNoKey() throws {
        let words = try XCTUnwrap(try AccountKey.make().words).joined(separator: " ")
        try "\(words)\nbacked-up\nhandle tony\n".write(to: folder.appendingPathComponent("account"), atomically: true, encoding: .utf8)

        XCTAssertNil(try store.record())
        XCTAssertNil(try store.key())
    }
}
