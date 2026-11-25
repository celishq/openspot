import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsEntryTests: PanelCase {
    private var landings: [String] {
        ((try? String(contentsOf: settingsLog, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    override func setUp() async throws {
        try await super.setUp()
        try writeSettings()
    }

    private func open(selecting id: String) async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    private func pressFix(_ link: String) throws {
        model.toast(.failure("Openspot cannot do that.", fix: .url(try XCTUnwrap(URL(string: link)))))
        model.toasts.press(try XCTUnwrap(model.toasts.queue.last).id)
    }

    func testCommandReturnOnACardOpensSettingsAtItsSpotAndNoSheet() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        try await open(selecting: "draw")

        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))

        try await wait("Settings at the spot") { self.landings == ["spot/draw"] }
        XCTAssertEqual(host.windows, [settingsID])
        XCTAssertNil(model.openSheetID)
    }

    func testAClickWithCommandOpensSettingsAtTheSpotAndRunsNothing() async throws {
        let log = folder.appendingPathComponent("calls")
        try script("conf", toml: "", "if [ \"$1\" = show ]; then printf 'item=a\\ntitle=A\\n'; else echo \"$@\" >> '\(log.path)'; fi")
        try await open(selecting: "conf")

        model.tap("conf", opening: true)

        try await wait("Settings at the spot") { self.landings == ["spot/conf"] }
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.path))
    }

    func testTheSettingsActionOfACardOpensSettingsAtItsSpot() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        await model.reload()

        XCTAssertTrue(model.act(.settings, on: "draw"))

        try await wait("Settings at the spot") { self.landings == ["spot/draw"] }
        XCTAssertNil(model.openSheetID)
    }

    func testReturnOnASpotOfCommandsWithNoSheetOpensSettingsAtItsSpot() async throws {
        try script("windows", toml: "title = 'Windows'\n[actions.left]\ntitle = 'Left'\n[actions.right]\ntitle = 'Right'", "")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(try XCTUnwrap(model.entries.first { $0.id == "windows" }))

        try await wait("Settings at the spot") { self.landings == ["spot/windows"] }
        XCTAssertNil(model.openSheetID)
    }

    func testAFixOfAMacAccessOpensSettingsAtThatAccess() async throws {
        await model.reload()

        try pressFix("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        try await wait("Settings at Screen Recording") { self.landings == ["access/screen"] }
        try pressFix("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        try await wait("Settings at the helper") { self.landings == ["access/screen", "access/helper"] }

        XCTAssertEqual(host.opened, [])
    }

    func testAFixThatIsNoMacAccessStillOpensItsLink() async throws {
        await model.reload()

        try pressFix("https://openspot.app/help")

        XCTAssertEqual(host.opened, [URL(string: "https://openspot.app/help")])
    }

    func testAFixOfAKeyOpensSettingsAtKeys() async throws {
        await model.reload()

        model.toast(.failure("Openspot cannot use `ctrl+space` to open, because another app uses it. Choose another key.", fix: .settings))
        model.toasts.press(try XCTUnwrap(model.toasts.queue.last).id)

        try await wait("Settings at Keys") { self.landings == ["keys"] }
    }

    func testCommandCommaOverAnOpenSheetOpensSettings() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("config"), withIntermediateDirectories: true)
        try "[[spots]]\nid = \"\(settingsID)\"\nkey = \"cmd+,\"\n".write(to: folder.appendingPathComponent("config/config.toml"), atomically: true, encoding: .utf8)
        try await open(selecting: "draw")
        model.runSelected()
        try await wait("the sheet") { self.model.openSheetID == "draw" }

        XCTAssertTrue(model.handleKey(ActionKey(name: ",", isCommand: true)))

        try await wait("the Settings window") { self.host.windows == [self.settingsID] }
    }

    func testCommandCommaOpensSettingsWithNoSetup() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        try await open(selecting: "draw")

        XCTAssertTrue(model.handleKey(ActionKey(name: ",", isCommand: true)))

        try await wait("the Settings window") { self.host.windows == [self.settingsID] }
    }

    func testASecretTypedInSettingsIsKeptAndAShortOneIsNot() async throws {
        try script("weather", toml: "title = 'Weather'\n[settings]\ntoken = 'secret'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()

        let short = await model.keep(secret: "abc", key: "token", of: "weather")
        let kept = await model.keep(secret: "tok-123456", key: "token", of: "weather")

        XCTAssertEqual(short, "Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value.")
        XCTAssertNil(kept)
        XCTAssertEqual(try model.files.secrets.read()["weather"]?["token"], "tok-123456")
    }
}
