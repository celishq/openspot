import XCTest
@testable import OpenspotCore

final class LoginItemTests: XCTestCase {
    private final class Fake: @unchecked Sendable {
        var isOn = false
    }

    private var folder: URL!
    private let fake = Fake()

    private var item: LoginItem {
        let fake = fake
        return LoginItem(isOn: { fake.isOn }, set: { fake.isOn = $0 })
    }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-login-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var settings: Settings {
        Settings(file: ConfigFile(url: folder.appendingPathComponent("config.toml")), folder: folder, login: item)
    }

    func testSettingsListsTheRowWithItsState() throws {
        let off = PluginOutput(text: try settings.answer(["read"])).items
        XCTAssertEqual(off.map(\.run), ["panel_key", LoginItem.run])
        XCTAssertEqual(off.last?.title, "Open at login")
        XCTAssertEqual(off.last?.isOn, false)

        fake.isOn = true
        XCTAssertEqual(PluginOutput(text: try settings.answer(["read"])).items.last?.isOn, true)
    }

    func testAPickOfTheRowTurnsItOnAndOff() throws {
        XCTAssertEqual(try settings.answer(["open", LoginItem.run]), "")
        XCTAssertTrue(fake.isOn)

        XCTAssertEqual(try settings.answer(["open", LoginItem.run]), "")
        XCTAssertFalse(fake.isOn)
    }

    func testAPickKeepsThePanelOpen() throws {
        XCTAssertEqual(PluginOutput(text: try settings.answer(["read"])).pick, .stay)
    }

    func testWithNoLoginItemSettingsShowsNoRow() throws {
        let plain = Settings(file: ConfigFile(url: folder.appendingPathComponent("config.toml")), folder: folder)

        XCTAssertEqual(PluginOutput(text: try plain.answer(["read"])).items.map(\.run), ["panel_key"])
    }
}
