import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsBookTests: PanelCase {
    private final class Login: @unchecked Sendable {
        var isOn = false
    }

    private let accesses = FakeAccesses()
    private let login = Login()

    private static let builtInTheme = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

    private var book: SettingsBook {
        model.settingsBook
    }

    private var config: Config {
        model.files.config.read()
    }

    override func setUp() async throws {
        try await super.setUp()
        let login = login
        let item = LoginItem(isOn: { login.isOn }, set: { login.isOn = $0 })
        model.runs.api = CommandAPI(mac: Mac(accesses: accesses, login: { item }, theme: Self.builtInTheme), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    private func read() async {
        await model.reload()
        await book.read()
    }

    private func land(_ place: String) throws {
        book.land(try XCTUnwrap(SettingsPage(place: place), "no place \(place)"))
    }

    private func row(_ item: String) throws -> SettingRow {
        try XCTUnwrap(book.rows.row(item), "no row \(item)")
    }

    func testTheFactsHoldEveryAccessSpotRowThemeAndTheAccount() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'", "openspot screen shot")
        accesses.set(.screen, to: .denied)

        await read()

        XCTAssertEqual(book.access.all.map(\.id), MacAccess.allCases)
        XCTAssertEqual(book.access.access(.screen)?.status, .denied)
        XCTAssertEqual(book.access.access(.screen)?.spots, ["cups"])
        XCTAssertEqual(book.spots.standing("cups")?.readiness, .access)
        XCTAssertEqual(book.spots.standing("cups")?.missing, [.screen])
        XCTAssertEqual(book.spots.standing("cups")?.uses.first { $0.id == .screen }?.needs, [.screen])
        XCTAssertFalse(book.spots.all.contains { $0.id.hasPrefix("openspot/") })
        XCTAssertEqual(try row("openspot/panel-key").kind, .key)
        XCTAssertEqual(try row("openspot/panel-key").value, "ctrl+space")
        XCTAssertEqual(try row("cups/key.fill").title, "Fill")
        XCTAssertEqual(book.looks.first { $0.isUsed }?.id, "Openspot")
        XCTAssertEqual(book.looks.first { $0.id == "Dracula" }?.colours.dark.accent.text, "#BD93F9")
        XCTAssertLessThan(try XCTUnwrap(book.looks.first { $0.id == "Retro Deck" }).layout.radius.card, try XCTUnwrap(book.looks.first { $0.id == "Openspot" }).layout.radius.card)
        XCTAssertEqual(book.account?.signedIn, false)
    }

    func testTheSearchFindsAccessesSpotsAndRowsByTheirFoldedWords() async throws {
        try script("cups", toml: "title = 'Café Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        let found = book.index.found("CAFE")
        let screen = book.index.found("screen rec")

        XCTAssertEqual(found.standings.map(\.id), ["cups"])
        XCTAssertEqual(screen.accesses.map(\.id), [.screen])
        XCTAssertTrue(book.index.found("zzz-none").isEmpty)
    }

    func testItLandsWhereTheWayInAsks() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        try land("access/screen")
        XCTAssertEqual(book.page, .accessOf(.screen))
        try land("spot/cups")
        XCTAssertEqual(book.page, .spotOf("cups"))
        try land("row/cups/key.fill")
        XCTAssertEqual(book.page, .spotOf("cups"))
        XCTAssertEqual(book.target, "cups/key.fill")
        try land("row/openspot/panel-key")
        XCTAssertEqual(book.page, .general)
        XCTAssertEqual(book.target, "openspot/panel-key")
        try land("keys")
        XCTAssertEqual(book.page, .general)
        try land("spot")
        XCTAssertEqual(book.page, .general)
        try land("account")
        XCTAssertEqual(book.page, .account)
        try land("search/screen")
        XCTAssertEqual(book.query, "screen")
    }

    func testSettingsOpensOnGeneralWithTheSectionsInTheirOrder() {
        XCTAssertEqual(SettingsBook().page, .general)
        XCTAssertEqual(SettingsPage.Section.sidebar, [.general, .look, .access, .developer])
        XCTAssertEqual(SettingsPage.Section.access.title, "Privacy")
        XCTAssertEqual(SettingsPage(place: "privacy"), .access)
        XCTAssertEqual(SettingsPage(place: "access"), .access)
    }

    func testADetailPageKeepsTheSectionItWasReachedFrom() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']", "openspot screen shot")
        await read()
        book.land(.spots)

        book.go(.spotOf("cups"))
        book.go(.accessOf(.screen))
        XCTAssertEqual(book.section, .spots)
        XCTAssertEqual(book.title, "Spots › \(MacAccess.screen.title)")
        book.goBack()
        XCTAssertEqual(book.section, .spots)
        book.go(.access)
        book.go(.spotOf("cups"))

        XCTAssertEqual(book.section, .access)
        XCTAssertEqual(book.title, "Access › Cups")
    }

    func testEachPlaceReadsBackFromItsWords() {
        let places: [SettingsPage] = [.access, .accessOf(.screen), .spotOf("tools/a"), .look, .account, .general, .developer, .row("openspot/panel-key"), .search("screen rec")]

        XCTAssertEqual(places.map { SettingsPage(place: $0.place) }, places)
        XCTAssertNil(SettingsPage(place: "access/nothing"))
        XCTAssertNil(SettingsPage(place: "nowhere"))
    }

    func testBackAndForwardWalkThePagesSeen() async throws {
        await read()
        book.land(.access)

        book.go(.developer)
        book.go(.look)
        book.goBack()
        XCTAssertEqual(book.page, .developer)
        book.goForward()

        XCTAssertEqual(book.page, .look)
        XCTAssertEqual(book.back, [.access, .developer])
    }

    func testASetWritesThroughSettingSetAndARemovalOfItsValueTakesItAway() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        await book.set(try row("openspot/fix-key"), to: "ctrl+option+f")
        await book.set(try row("cups/open"), to: "ctrl+option+k")

        XCTAssertEqual(config.fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertEqual(try row("cups/open").value, "ctrl+option+k")
        await book.set(try row("cups/open"), to: "")
        XCTAssertNil(try row("cups/open").value)
    }

    func testARecordedKeyBecomesTheValueOfItsRow() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        book.startRecording(try row("cups/open"))
        XCTAssertTrue(book.record(key: "k", modifiers: ["ctrl", "option"]))

        try await wait("the recorded key") { (try? self.row("cups/open").value) == "ctrl+option+k" }
        XCTAssertNil(book.recording)
    }

    func testBackspaceWhileRecordingRemovesTheKeyOfASpotAndOfTheApp() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()
        await book.set(try row("cups/open"), to: "ctrl+option+k")
        await book.set(try row("openspot/fix-key"), to: "ctrl+option+f")

        book.startRecording(try row("cups/open"))
        XCTAssertTrue(book.record(key: "backspace", modifiers: []))
        try await wait("the spot's key removed") { (try? self.row("cups/open").value) == nil }
        book.startRecording(try row("openspot/fix-key"))
        XCTAssertTrue(book.record(key: "backspace", modifiers: []))
        try await wait("the app's key removed") { self.config.fixKey != Shortcut(text: "ctrl+option+f") }
        XCTAssertNil(book.recording)
    }

    func testRemoveTakesAwayASecret() async throws {
        try script("weather", toml: "title = 'Weather'\n[settings]\ntoken = 'secret'", "")
        try model.files.secrets.keep("MARKER-7f3c", key: "token", of: "weather")
        await read()

        await book.remove(try row("weather/token"))

        XCTAssertNil(try model.files.secrets.read()["weather"]?["token"])
        XCTAssertEqual(try row("weather/token").kind, .secret)
        XCTAssertNil(try row("weather/token").value)
    }

    func testASecretTypedInSettingsIsKeptAndAShortOneIsNot() async throws {
        try script("weather", toml: "title = 'Weather'\n[settings]\ntoken = 'secret'", "")
        await read()

        await book.keep(secret: "abc", of: try row("weather/token"))
        await book.keep(secret: "tok-123456", of: try row("weather/token"))

        XCTAssertEqual(model.toasts.queue.map(\.words), ["Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value."])
        XCTAssertEqual(try model.files.secrets.read()["weather"]?["token"], "tok-123456")
        XCTAssertEqual(try row("weather/token").value, SettingRow.secretValue)
    }

    func testAChoiceWithNoValueShowsItsDefault() {
        let row = SettingRow(spot: "notes", name: "Notes", key: "sort", title: "Sort", value: nil, kind: .choice, section: .spots, icon: "", options: ["name", "date"], default: "date")

        XCTAssertEqual(book.value(of: row), .text("date"))
    }

    func testAValueReadsAsItsKind() {
        let toggle = SettingRow(spot: "notes", name: "Notes", key: "menubar", title: "Menu bar", value: "true", kind: .toggle, section: .spots, icon: "")
        let key = SettingRow(spot: "notes", name: "Notes", key: "open", title: "Open", value: "ctrl+option+k", kind: .key, section: .spots, icon: "")
        let secret = SettingRow(spot: "notes", name: "Notes", key: "token", title: "Token", value: SettingRow.secretValue, kind: .secret, section: .spots, icon: "")

        XCTAssertTrue(book.value(of: toggle).isOn)
        XCTAssertEqual(book.value(of: key).caps, ["⌃", "⌥", "K"])
        XCTAssertEqual(book.value(of: secret).word, "Set")
    }

    func testAToggleOfTheAppGoesToTheMac() async throws {
        await read()

        await book.set(try row("openspot/login"), to: "true")

        XCTAssertTrue(login.isOn)
    }

    func testAThemeIsUsedThroughThemeUse() async throws {
        await read()

        await book.use(theme: "Dracula")

        XCTAssertEqual(config.theme, "Dracula")
        XCTAssertEqual(book.looks.first { $0.isUsed }?.id, "Dracula")
    }

    func testAThemePromptAsksForTheWordsOverTheThemeInUse() async throws {
        await read()
        await book.use(theme: "Dracula")

        let asked = await book.themePrompt(words: "warm sunset colours")
        let prompt = try XCTUnwrap(asked)

        XCTAssertTrue(prompt.contains("its theme Dracula: warm sunset colours"))
    }

    func testAFailedActSaysWhyInAToast() async throws {
        await read()

        await book.use(theme: "Gone")

        XCTAssertEqual(model.toasts.queue.map(\.words), ["There is no theme named Gone. Run `openspot theme list` to see each one."])
        XCTAssertFalse(book.looks.isEmpty)
    }

    func testAllowStartsTheGuidedGrantAndEndGrantEndsIt() async throws {
        try script("agenda", toml: "title = 'Agenda'\nuses = ['calendar']", "openspot calendar events")
        accesses.set(.calendars, to: .denied)
        await read()

        await book.allow("agenda")

        XCTAssertEqual(book.grant?.spot, "agenda")
        XCTAssertEqual(book.grant?.step, .calendars)
        XCTAssertEqual(book.grant?.step?.place, "Privacy & Security › Calendars")
        await book.endGrant()
        XCTAssertNil(book.grant)
    }

    func testAskOpensThePaneOfAnAccessAndAsksForAccessibility() async throws {
        await read()

        await book.ask(.screen)
        await book.ask(.helper)

        XCTAssertEqual(host.opened, [MacAccess.screen.pane, MacAccess.helper.pane].compactMap { $0 })
    }

    func testNewMakesTheAccountAndTheFactsShowIt() async throws {
        await read()

        await book.makeAccount(handle: "tony")

        XCTAssertEqual(book.account?.signedIn, true)
        XCTAssertEqual(book.account?.handle, "tony")
        XCTAssertEqual(try model.files.account.record()?.handle, "tony")
    }

    func testAHandleThatBreaksTheRuleSaysTheRuleInAToast() async throws {
        await read()

        await book.makeAccount(handle: "T")

        XCTAssertEqual(model.toasts.queue.map(\.words), [AccountHandle.rule])
        XCTAssertNil(try model.files.account.key())
    }

    func testSignOutAsksTouchIDThenRemovesTheKey() async throws {
        _ = try model.files.account.keyMadeOnce()
        await read()

        await book.signOut()

        XCTAssertNil(try model.files.account.key())
        XCTAssertEqual(book.account?.signedIn, false)
        XCTAssertEqual(host.asked, ["sign out of your account"])
    }

    func testTheGridAndTheFactsLeaveOutClashFreeKeysAndMarkClashes() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        try script("mugs", toml: "title = 'Mugs'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        await book.set(try row("cups/open"), to: "ctrl+option+k")
        await book.set(try row("mugs/open"), to: "option+ctrl+k")

        XCTAssertEqual(book.keys.clashing, ["cups/open", "mugs/open"])
        XCTAssertEqual(book.keys.clash(of: "cups/open"), "Also Mugs · Open")
        XCTAssertNil(book.keys.clash(of: "cups/key.fill"))
    }

    func testAUseSaysTheAccessItNeedsAndMayAskFor() {
        XCTAssertEqual(SpotStanding.UseNeeds(id: .screen, needs: [.screen], maybe: [.camera, .microphone]).needsLine, "Needs Screen Recording · May ask for Camera and Microphone")
        XCTAssertNil(SpotStanding.UseNeeds(id: .clipboard, needs: [], maybe: []).needsLine)
    }

    func testTheFactsSayWhatAPageShowsSoTheWindowOnlyDrawsIt() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'\n[settings]\ncity = 'text'", "openspot screen shot")
        accesses.set(.screen, to: .denied)
        await read()
        let cups = try XCTUnwrap(book.spots.standing("cups"))

        XCTAssertEqual(book.rows.groups(of: "cups").map(\.id), ["Keyboard Shortcuts", "Settings", "Where It Shows"])
        XCTAssertEqual(book.rows.groups(of: "cups")[1].rows.map(\.key), ["city"])
        XCTAssertEqual(cups.banner?.title, "Cups can’t run yet")
        XCTAssertEqual(cups.banner?.line, "It needs Screen Recording from macOS.")
        XCTAssertEqual(cups.lack, "Needs Screen Recording")
        XCTAssertEqual(book.access.needed.map(\.id), [.screen])
        XCTAssertFalse(book.access.unneeded.contains { $0.id == .screen })
        XCTAssertEqual(book.spots.waiting.map(\.id), ["cups"])
        XCTAssertEqual(Set(book.looks.map(\.group)), ["Built In"])
        XCTAssertEqual(AccessGrant(spot: "cups", steps: [.screen]).title(of: "Cups"), "Cups needs Screen Recording")
        XCTAssertEqual(Shortcut.caps("cmd+shift+space"), ["⇧", "⌘", "Space"])
    }
}
