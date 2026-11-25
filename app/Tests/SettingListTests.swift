import XCTest
@testable import OpenspotCore

final class SettingListTests: XCTestCase {
    private struct Row: Equatable {
        let item: String
        let key: String
        let title: String
        let value: String?
        let kind: String
        let section: String
    }

    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("setting-list-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_SPOTS": folder.appendingPathComponent("spots").path]
    }

    private var places: AppPlaces {
        .test(environment)
    }

    private func answer(_ arguments: [String], mac: Mac = Mac(), app: (any RunningApp)? = nil) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: mac, places: places, app: app).work(for: call, request: .test(arguments, in: environment), input: { "" }))
        return await work()
    }

    private func rows(_ arguments: [String], mac: Mac = Mac(), app: (any RunningApp)? = nil) async throws -> [Row] {
        let answer = try await answer(["setting", "list"] + arguments, mac: mac, app: app)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return TextBlock.blocks(in: answer.output).map { block in
            Row(item: block.value("item") ?? "", key: block.value("key") ?? "", title: block.value("title") ?? "", value: block.value("value"), kind: block.value("kind") ?? "", section: block.value("section") ?? "")
        }
    }

    private func writeWeather() throws {
        let toml = "title = 'Weather'\n[actions.refresh]\ntitle = 'Refresh'\n[settings]\ncity = { type = 'text', title = 'City' }\ntoken = { type = 'secret', title = 'Token' }"
        try TestSpot(toml: toml, body: "echo").write(to: folder.appendingPathComponent("spots").spotFile("weather"))
        try places.config.change {
            $0.assign(Trigger(text: "ctrl+option+w"), to: "weather", act: .open)
            $0.set(setting: "city", of: "weather", to: "Paris")
        }
        try places.secrets.keep("MARKER-7f3c", key: "token", of: "weather")
    }

    private var weather: [Row] {
        [
            Row(item: "weather/open", key: "open", title: "Open", value: "ctrl+option+w", kind: "key", section: "spot"),
            Row(item: "weather/key.refresh", key: "key.refresh", title: "Refresh", value: nil, kind: "key", section: "spot"),
            Row(item: "weather/float", key: "float", title: "Float", value: nil, kind: "key", section: "spot"),
            Row(item: "weather/city", key: "city", title: "City", value: "Paris", kind: "field", section: "spot"),
            Row(item: "weather/token", key: "token", title: "Token", value: "set", kind: "secret", section: "spot"),
            Row(item: "weather/menubar", key: "menubar", title: "Show in the menu bar", value: "false", kind: "toggle", section: "spot"),
            Row(item: "weather/window", key: "window", title: "Open in a window", value: "false", kind: "toggle", section: "spot")
        ]
    }

    func testTheRowsOfASpotAreTheRowsOfItsSettingsSheetAndHideTheSecret() async throws {
        try writeWeather()

        let answer = try await answer(["setting", "list", "--spot", "weather"])

        let rows = try await rows(["--spot", "weather"])

        XCTAssertFalse(answer.output.contains("MARKER"), answer.output)
        XCTAssertEqual(rows, weather)
        XCTAssertEqual(Set(TextBlock.blocks(in: answer.output).map { $0.value("name") }), ["Weather"])
    }

    func testTheRowsOfTheAppAreItsKeysItsMacChoicesAndItsTheme() async throws {
        try places.config.change {
            $0.set(Shortcut(text: "option+space") ?? .standard, for: "panel-key")
            $0.set(theme: ThemeFolder.builtInName)
        }
        let app = FakeRunningApp()
        await app.offerSlowMotion()
        let mac = Mac(login: { LoginItem(isOn: { true }, set: { _ in }) })

        let rows = try await rows(["--spot", "openspot"], mac: mac, app: app)
        let names = try await answer(["setting", "list", "--spot", "openspot"], mac: mac, app: app).output

        XCTAssertEqual(Set(TextBlock.blocks(in: names).map { $0.value("name") }), ["Openspot"])
        XCTAssertEqual(rows, [
            Row(item: "openspot/panel-key", key: "panel-key", title: "Open Openspot", value: "option+space", kind: "key", section: "general"),
            Row(item: "openspot/fix-key", key: "fix-key", title: "Open a fix", value: "cmd+option+o", kind: "key", section: "general"),
            Row(item: "openspot/slow", key: "slow", title: "Slow motion", value: "false", kind: "toggle", section: "developer"),
            Row(item: "openspot/login", key: "login", title: "Open at login", value: "true", kind: "toggle", section: "general"),
            Row(item: "openspot/theme", key: "theme", title: "Theme", value: ThemeFolder.builtInName, kind: "choice", section: "look")
        ])
    }

    func testTheWholeListHoldsTheAppAndEachSpotAndNoCarefulRow() async throws {
        try writeWeather()

        let rows = try await rows([])

        XCTAssertEqual(rows.filter { $0.item.hasPrefix("weather/") }, weather)
        XCTAssertEqual(rows.prefix(2).map(\.item), ["openspot/panel-key", "openspot/fix-key"])
        XCTAssertFalse(rows.contains { $0.key == "careful" })
        XCTAssertEqual(Set(rows.map(\.item)).count, rows.count)
    }

    func testTheListPrintsJSON() async throws {
        try writeWeather()

        let answer = try await answer(["setting", "list", "--spot", "weather", "--json"])
        let records = try JSONSerialization.jsonObject(with: Data(answer.output.utf8)) as? [[String: String]]

        XCTAssertEqual(records?.map { $0["item"] }, weather.map(\.item))
        XCTAssertEqual(records?.first { $0["key"] == "token" }?["value"], "set")
    }

    func testASpotThatCannotShowInTheMenuBarHasNoMenuBarOrWindowRow() throws {
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let settings = SpotSettings(spot: "notes", fields: [], showsInMenuBar: false, keys: [])

        XCTAssertEqual(settings.rows(in: file.read(), secrets: [:]), [])
    }

    func testASpotThatAlwaysOpensAsAWindowHasNoWindowRow() async throws {
        try TestSpot(toml: "title = 'Board'\nwindow = 'settings'").write(to: folder.appendingPathComponent("spots").spotFile("board"))

        let rows = try await rows(["--spot", "board"])

        XCTAssertEqual(rows.map(\.key), ["open", "float", "menubar"])
    }

    func testEachKeyOfTheListIsOneThatSettingSetTakes() async throws {
        try writeWeather()

        let window = try await answer(["setting", "set", "--spot", "weather", "window", "true"])
        let theme = try await answer(["setting", "set", "--spot", "openspot", "theme", ThemeFolder.builtInName], mac: Mac(theme: builtInURL))

        let rows = try await rows(["--spot", "weather"])

        XCTAssertEqual([window.code, theme.code], [0, 0], window.errors + theme.errors)
        XCTAssertEqual(rows.first { $0.key == "window" }?.value, "true")
        XCTAssertEqual(places.config.read().theme, ThemeFolder.builtInName)
        XCTAssertNil(places.config.read().setting("window", of: "weather"))
    }

    func testAnUnknownSpotFails() async throws {
        let answer = try await answer(["setting", "list", "--spot", "gone"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.output, "")
    }

    func testTheListOfItsOwnFolderNeedsNoUse() {
        XCTAssertNil(SpotUseCall(arguments: ["setting", "list", "--spot", "openspot"], of: "openspot/settings"))
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "list", "--spot", "openspot"], of: "notes")?.use, .spots)
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "list"], of: "openspot/settings")?.use, .spots)
    }
}
