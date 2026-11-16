import XCTest
@testable import OpenspotCore

@MainActor
final class CallInputTests: SpotRunsCase {
    private let marker = "MARKER-7f3c"

    private func text(_ name: String) -> String {
        (try? String(contentsOfFile: path(name), encoding: .utf8)) ?? ""
    }

    @discardableResult
    private func secrets(_ values: [String: String] = [:], of spot: String = "script") throws -> SecretStore {
        let store = SecretStore(file: folder.appendingPathComponent("secrets.json"))
        for (key, value) in values { try store.keep(value, key: key, of: spot) }
        runs.secrets = store
        return store
    }

    private func everything(in folder: URL) -> String {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    func testACallCarriesTheValuesOfTheFieldsOfItsOwnHeaderAndOfNoOtherSpot() async throws {
        try script(header: "on=sheet.open\n\nfield=folder\n\nfield=api-key", "env | grep '^OPENSPOT_SETTING_' | sort > '\(path("env"))'")
        try script("other", header: "on=sheet.open\n\nfield=folder", log: "other", "")
        let sheet = try sheet()
        runs.take(settings: [
            SpotSetting(spot: "script", key: "folder", value: "/tmp/repos"),
            SpotSetting(spot: "script", key: "api-key", value: "k1"),
            SpotSetting(spot: "script", key: "kept", value: "not declared"),
            SpotSetting(spot: "other", key: "folder", value: "/tmp/other")
        ])

        sheet.read(need: .change)

        try await wait("the call") { self.text("env").hasSuffix("\n") }
        XCTAssertEqual(text("env"), "OPENSPOT_SETTING_API_KEY=k1\nOPENSPOT_SETTING_FOLDER=/tmp/repos\n")
    }

    func testAnActionAndAPickOfARowCarryTheKeysOfThatRowOnStdin() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\nmeeting=https://meet.example/a\\n\\nrow=b\\ntitle=B\\n' ;;
          *) { echo "$*"; cat; echo; } >> '\(path("input"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.read(need: .change)
        try await wait("the rows") { sheet.list.all.count == 2 && !sheet.isReading }
        let row = try XCTUnwrap(sheet.list.all.first)

        sheet.run(CommandAction(id: "join", title: "Join"), item: row)
        try await wait("the action") { self.text("input").contains("join a") && sheet.calls.isEmpty }
        sheet.pick(row)

        try await wait("the pick") { self.text("input").contains("open a\nrow=a") && self.text("input").hasSuffix("\n\n") }
        XCTAssertEqual(text("input"), "join a\nrow=a\ntitle=A\nmeeting=https://meet.example/a\n\nopen a\nrow=a\ntitle=A\nmeeting=https://meet.example/a\n\n")
    }

    func testTheValueOfASecretFieldGoesOnlyOnStdinAndTheHostRecordsItNowhere() async throws {
        let logs = folder.appendingPathComponent("logs")
        let stats = folder.appendingPathComponent("stats")
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, clock: clock.value, stopPause: 0.2, log: CallLog(folder: logs), stats: stats)
        var told: [String] = []
        runs.onReport = { _, report in
            switch report {
            case .toast(let text), .failure(let text), .failureWithFix(let text, _): told.append(text)
            default: break
            }
        }
        try script(header: "on=sheet.open\n\nfield=token\ntype=secret", """
        env > '\(path("env"))'
        echo "$*" > '\(path("arguments"))'
        in=$(cat)
        token=$(printf '%s\\n' "$in" | sed -n 's/^setting.token=//p')
        printf '%s' "$token" > '\(path("seen"))'
        printf 'toast=Got %s\\n\\nrow=a\\ntitle=%s\\n---\\n' "$token" "$token"
        echo "Cannot reach the server with $token" >&2
        exit 1
        """)
        let sheet = try sheet()
        try secrets(["token": marker])

        sheet.pressCard()

        try await wait("the toast and the failure") { told.contains("Got •••") && told.contains("Cannot reach the server with •••") }
        try await allEnded()
        runs.quit()
        _ = CallLog(folder: logs).text(of: "script")
        XCTAssertEqual(text("seen"), marker)
        XCTAssertFalse(text("env").contains(marker))
        XCTAssertFalse(text("arguments").contains(marker))
        XCTAssertFalse(told.joined().contains(marker))
        XCTAssertEqual(sheet.failure, "Cannot reach the server with •••")
        XCTAssertTrue(everything(in: logs).contains("Cannot reach the server with •••"))
        XCTAssertFalse(everything(in: logs).contains(marker))
        XCTAssertFalse(everything(in: stats).isEmpty)
        XCTAssertFalse(everything(in: stats).contains(marker))
    }

    func testAFormCallThatFailsHidesTheSecretInItsFailure() async throws {
        runs.onReport = { _, _ in }
        try script(header: "on=sheet.open\n\nfield=token\ntype=secret", """
        token=$(sed -n 's/^setting.token=//p')
        case "$1" in
          login) echo "Cannot reach the server with $token" >&2; exit 1 ;;
        esac
        """)
        let sheet = try sheet()
        try secrets(["token": marker])

        do {
            _ = try await sheet.form(CommandAction(id: "login", title: "Log in"), item: nil)
            XCTFail("The form call should fail.")
        } catch {
            XCTAssertEqual(SpotsModel.reason(error), "Cannot reach the server with •••")
        }
    }

    func testAPlainFieldNeverGetsTheSecretThatAnOlderHeaderKeptUnderItsKey() async throws {
        try script(header: "on=sheet.open\n\nfield=token", "env > '\(path("env"))'\ncat > '\(path("input"))'")
        let sheet = try sheet()
        try secrets(["token": marker])

        sheet.read(need: .change)

        try await wait("the call") { self.text("env").contains("OPENSPOT_ID") && !sheet.isReading }
        XCTAssertFalse(text("env").contains(marker))
        XCTAssertFalse(text("input").contains(marker))
    }

    func testASettingOver64KBIsNotPutInTheEnvironment() async throws {
        try script(header: "on=sheet.open\n\nfield=notes\n\nfield=city", "env | grep '^OPENSPOT_SETTING_' | cut -c1-30 > '\(path("env"))'")
        let sheet = try sheet()
        runs.take(settings: [
            SpotSetting(spot: "script", key: "notes", value: String(repeating: "n", count: 65_537)),
            SpotSetting(spot: "script", key: "city", value: "Paris")
        ])

        sheet.read(need: .change)

        try await wait("the call") { self.text("env").hasSuffix("\n") }
        XCTAssertEqual(text("env"), "OPENSPOT_SETTING_CITY=Paris\n")
    }

    private func settingsSheet(fields: [CommandOffer], config: String = "") throws -> String {
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        try config.write(to: file.url, atomically: true, encoding: .utf8)
        let settings = SpotSettings(file: file, secrets: try secrets(["token": marker]), spot: "script", fields: fields, showsInMenuBar: false)
        return try settings.answer(["read"])
    }

    private func field(_ key: String, secret: Bool) throws -> CommandOffer {
        try XCTUnwrap(CommandOffer(setting: TextBlock(fields: [.init(key: "field", value: key)] + (secret ? [.init(key: "type", value: "secret")] : []))))
    }

    func testTheSettingsSheetShowsThatASecretIsSetAndNotItsValue() throws {
        let sheet = try settingsSheet(fields: [field("token", secret: true)])

        XCTAssertFalse(sheet.contains(marker))
        XCTAssertTrue(sheet.contains("detail=Set, and hidden"))
    }

    func testASecretShowsNeitherInAPlainFieldOfItsKeyNorAsAKeptValue() throws {
        let plain = try settingsSheet(fields: [field("token", secret: false)])
        let dropped = try settingsSheet(fields: [], config: "[[settings]]\nspot = \"script\"\nkey = \"city\"\nvalue = \"Paris\"\n")

        XCTAssertFalse(plain.contains(marker))
        XCTAssertTrue(plain.contains("detail=Not set"))
        XCTAssertFalse(dropped.contains(marker))
        XCTAssertFalse(dropped.contains("token"))
        XCTAssertTrue(dropped.contains("detail=Paris"))
    }

    func testRemoveOnTheRowOfASecretDropsItFromTheStore() throws {
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let store = try secrets(["token": marker])
        let settings = try SpotSettings(file: file, secrets: store, spot: "script", fields: [field("token", secret: true)], showsInMenuBar: false)

        _ = try settings.answer(["clear", "setting:script:token"])

        XCTAssertEqual(try SecretStore(file: store.file).read(), [:])
        XCTAssertNil(file.read().setting("token", of: "script"))
    }
}
