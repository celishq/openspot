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
        book.land(try XCTUnwrap(SettingsPlace(place: place), "no place \(place)"))
    }

    private func row(_ item: String) throws -> SettingRow {
        try XCTUnwrap(book.rows.row(item), "no row \(item)")
    }

    func testASourceShowsBesideTheSearchFieldAmongItsPlacesAndNamesTheAccessItsReadNeeds() async throws {
        try script("tab", toml: "title = 'Tab'\nicon = 'safari'\ndetail = 'Hand the front tab to a spot'\nuses = ['attachment', 'read', 'clipboard']\n\n[on]\n\"panel.open\" = true", "openspot selection read com.apple.Safari")

        await read()

        let standing = try XCTUnwrap(book.spots.standing("tab"))
        XCTAssertEqual(book.rows.groups(of: "tab").first { $0.id == SettingRows.placesGroup }?.rows.first?.key, "attachment")
        XCTAssertEqual(SpotPlace(rawValue: "attachment"), .searchField)
        XCTAssertEqual(SpotPlace.searchField.name, "Search Field")
        XCTAssertEqual(standing.accesses, [.accessibility, .automation])
        XCTAssertEqual(try row("tab/attachment").title, "Show beside the search field")
        XCTAssertNil(try row("tab/attachment").detail)
        XCTAssertEqual(SpotPlace.searchField.info, "When the panel opens, what this spot reads shows on the right of the search field. Press Tab to hand it to a spot.")
        XCTAssertEqual(standing.spot.attachmentLook, .symbol("safari"))
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
        XCTAssertEqual(book.spots.standing("cups")?.accesses, [.screen])
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

        let found = book.index.matching("CAFE")
        let screen = book.index.matching("screen rec")

        XCTAssertEqual(found.standings.map(\.id), ["cups"])
        XCTAssertEqual(screen.accesses.map(\.id), [.screen])
        XCTAssertTrue(book.index.matching("zzz-none").isEmpty)
    }

    func testTheSearchRanksRowsByWordsInAnyOrderAsThePanelDoes() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill Cups'\n[actions.later]\ntitle = 'Cups Fill Later'", "")
        await read()

        let found = book.index.matching("cups fill").rows.map(\.item)
        let initials = book.index.matching("fc").rows.map(\.item)

        XCTAssertEqual(found.filter { $0.hasPrefix("cups/key.") }, ["cups/key.later", "cups/key.fill"])
        XCTAssertEqual(initials.filter { $0.hasPrefix("cups/key.") }, ["cups/key.fill"])
    }

    func testASearchForShortcutOrKeyListsEveryShortcut() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        let shortcuts = book.index.matching("shortcut").rows
        let keys = book.index.matching("key").rows.filter { $0.kind == .key }

        XCTAssertEqual(Set(shortcuts.map(\.item)), Set(book.rows.all.filter { $0.kind == .key }.map(\.item)))
        XCTAssertTrue(shortcuts.contains { $0.item == "cups/key.fill" })
        XCTAssertEqual(Set(keys.map(\.item)), Set(shortcuts.map(\.item)))
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
        XCTAssertEqual(SettingsPage.Section.allCases, [.general, .look, .access, .developer])
        XCTAssertEqual(SettingsPage.Section.access.title, "Privacy")
        XCTAssertEqual(SettingsPlace(place: "privacy"), .access)
        XCTAssertEqual(SettingsPlace(place: "access"), .access)
    }

    func testASpotPageMarksItsRowAndAnAccessPageKeepsTheMarkItCameFrom() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']", "openspot screen shot")
        await read()
        book.land(.general)

        book.go(.spotOf("cups"))
        XCTAssertEqual(book.mark, .spotOf("cups"))
        XCTAssertEqual(book.title, "Cups")
        book.go(.accessOf(.screen))
        XCTAssertEqual(book.mark, .spotOf("cups"))
        XCTAssertEqual(book.title, "Cups › \(MacAccess.screen.title)")
        book.go(.access)
        book.go(.accessOf(.screen))

        XCTAssertEqual(book.mark, .access)
        XCTAssertEqual(book.title, "Privacy › \(MacAccess.screen.title)")
        book.goBack()
        book.goBack()
        XCTAssertEqual(book.mark, .spotOf("cups"))
    }

    func testTheSidebarListsEachSpotOnceByNameAndASearchNarrowsIt() async throws {
        try script("mugs", toml: "title = 'Mugs'\n[actions.pour]\ntitle = 'Pour'", "")
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'", "openspot screen shot")
        accesses.set(.screen, to: .denied)
        await read()

        XCTAssertEqual(book.shownSpots.filter { ["cups", "mugs"].contains($0.id) }.map(\.id), ["cups", "mugs"])
        XCTAssertTrue(try XCTUnwrap(book.shownSpots.first { $0.id == "cups" }).lacks)
        book.search("pour")

        XCTAssertEqual(book.shownSpots.map(\.id), ["mugs"])
        book.search("")
        XCTAssertGreaterThan(book.shownSpots.count, 1)
    }

    func testEachPlaceReadsBackFromItsWords() {
        let places: [SettingsPlace] = [.access, .accessOf(.screen), .spotOf("tools/a"), .look, .account, .general, .developer, .row("openspot/panel-key"), .search("screen rec")]

        XCTAssertEqual(places.map { SettingsPlace(place: $0.place) }, places)
        XCTAssertNil(SettingsPlace(place: "access/nothing"))
        XCTAssertNil(SettingsPlace(place: "nowhere"))
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
        XCTAssertEqual(book.trail.back.map(\.page), [.access, .developer])
    }

    func testBackReturnsToTheVisitThatWasLeftAndAFreshGoIsANewVisit() async throws {
        await read()
        book.land(.access)
        let first = book.trail.now.visit

        book.go(.developer)
        XCTAssertNotEqual(book.trail.now.visit, first)
        book.goBack()
        XCTAssertEqual(book.trail.now.visit, first)
        book.go(.developer)

        XCTAssertNotEqual(book.trail.now.visit, first)
        XCTAssertEqual(Set([first, book.trail.back.last?.visit]).count, 1)
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
        let row = SettingRow(spot: "notes", name: "Notes", key: "sort", title: "Sort", value: nil, kind: .choice, section: nil, icon: "", options: ["name", "date"], default: "date")

        XCTAssertEqual(book.value(of: row), .text("date"))
    }

    func testAValueReadsAsItsKind() {
        let toggle = SettingRow(spot: "notes", name: "Notes", key: "menubar", title: "Menu bar", value: "true", kind: .toggle, section: nil, icon: "")
        let key = SettingRow(spot: "notes", name: "Notes", key: "open", title: "Open", value: "ctrl+option+k", kind: .key, section: nil, icon: "")
        let secret = SettingRow(spot: "notes", name: "Notes", key: "token", title: "Token", value: SettingRow.secretValue, kind: .secret, section: nil, icon: "")

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

    func testADuplicateOfAThemeIsYoursAndInUseAndAMoveToTheTrashTakesItAway() async throws {
        await read()

        await book.duplicate(theme: "Dracula")
        let copy = try XCTUnwrap(book.looks.first { $0.isUsed })
        XCTAssertFalse(copy.isBuiltIn)
        XCTAssertEqual(copy.colours, book.looks.first { $0.id == "Dracula" }?.colours)
        await book.delete(theme: copy.id)

        XCTAssertFalse(book.looks.contains { $0.id == copy.id })
        XCTAssertEqual(model.toasts.queue.last?.words, "Moved the theme \(copy.id) to the Trash, and switched to the theme Openspot.")
    }

    func testAThemePromptAsksForTheWordsOverTheThemeInUse() async throws {
        await read()
        await book.use(theme: "Dracula")

        let asked = await book.themePrompt(words: "warm sunset colours")
        let prompt = try XCTUnwrap(asked)

        XCTAssertTrue(prompt.contains("its theme Dracula"), prompt)
        XCTAssertTrue(prompt.hasSuffix("<request>\nwarm sunset colours\n</request>"), prompt)
    }

    func testAThemePromptWithNoWordsAsksForThemAndCopiesNothing() async throws {
        await read()

        let asked = await book.themePrompt(words: "")

        XCTAssertNil(asked)
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

    func testAllowOfAnAccessStartsTheSameGuidedGrantAtItsPage() async throws {
        accesses.set(.screen, to: .denied)
        await read()
        book.land(.access)

        await book.allow(access: .screen)

        XCTAssertNil(book.grant?.spot)
        XCTAssertEqual(book.grant?.steps, [.screen])
        XCTAssertEqual(book.grant?.title(of: nil), "Allow Screen Recording")
        XCTAssertEqual(book.page, .accessOf(.screen))
        await book.endGrant()
        XCTAssertNil(book.grant)
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

        XCTAssertEqual(book.rows.clashing, ["cups/open", "mugs/open"])
        XCTAssertEqual(book.rows.clash(of: "cups/open"), "Also Mugs · Open")
        XCTAssertNil(book.rows.clash(of: "cups/key.fill"))
    }

    func testAUseSaysTheAccessItNeedsAndMayAskFor() {
        XCTAssertEqual(SpotStanding.UseNeeds(id: .screen, needs: [.screen], maybe: [.camera, .microphone]).needsLine, "Needs Screen Recording · May ask for Camera and Microphone")
        XCTAssertNil(SpotStanding.UseNeeds(id: .clipboard, needs: [], maybe: []).needsLine)
    }

    func testTheFactsSayWhatAPageShowsSoTheWindowOnlyDrawsIt() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'\n[settings]\ncity = 'text'\nkeep = { type = 'bool', title = 'Keep' }", "openspot screen shot")
        accesses.set(.screen, to: .denied)
        await read()
        let cups = try XCTUnwrap(book.spots.standing("cups"))

        XCTAssertEqual(book.rows.groups(of: "cups").map(\.id), ["Shortcuts", "Settings", "Where It Shows"])
        XCTAssertEqual(book.rows.groups(of: "cups")[1].rows.map(\.key), ["city", "keep"])
        XCTAssertEqual(book.rows.groups(of: "cups")[2].rows.map(\.key), ["menubar", "window"])
        XCTAssertEqual(cups.banner?.title, "Cups can’t run yet")
        XCTAssertEqual(cups.banner?.line, "It needs Screen Recording from macOS.")
        XCTAssertEqual(cups.lack, "Needs Screen Recording")
        XCTAssertEqual(book.access.needed.map(\.id), [.screen])
        XCTAssertFalse(book.access.unneeded.contains { $0.id == .screen })
        XCTAssertEqual(book.spots.waiting.map(\.id), ["cups"])
        XCTAssertTrue(book.looks.allSatisfy(\.isBuiltIn))
        XCTAssertEqual(AccessGrant(spot: "cups", steps: [.screen]).title(of: "Cups"), "Cups needs Screen Recording")
        XCTAssertEqual(Shortcut.caps("cmd+shift+space"), ["⇧", "⌘", "Space"])
    }
}
