import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsEntryTests: PanelCase {
    private var book: SettingsBook {
        model.settingsBook
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

        XCTAssertEqual(host.settingsOpens, 1)
        XCTAssertEqual(book.page, .spotOf("draw"))
        XCTAssertNil(model.openSheetID)
    }

    func testTheSettingsActionOfACardOpensSettingsAtItsSpot() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        await model.reload()

        XCTAssertTrue(model.openSettings(at: .spotOf("draw")))

        XCTAssertEqual(book.page, .spotOf("draw"))
        XCTAssertNil(model.openSheetID)
    }

    func testReturnOnASpotOfCommandsWithNoSheetOpensSettingsAtItsSpot() async throws {
        try script("windows", toml: "title = 'Windows'\n[actions.left]\ntitle = 'Left'\n[actions.right]\ntitle = 'Right'", "")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(try XCTUnwrap(model.entries.first { $0.id == "windows" }))

        XCTAssertEqual(book.page, .spotOf("windows"))
        XCTAssertNil(model.openSheetID)
    }

    func testAFixOfAMacAccessOpensSettingsAtThatAccess() async throws {
        await model.reload()

        try pressFix("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        try await wait("Settings at Screen Recording") { self.book.page == .accessOf(.screen) }
        try pressFix("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        try await wait("Settings at the helper") { self.book.page == .accessOf(.helper) }

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

        try await wait("Settings at Keys") { self.book.page == .keys }
    }

    func testCommandCommaOverAnOpenSheetOpensSettings() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        try await open(selecting: "draw")
        model.runSelected()
        try await wait("the sheet") { self.model.openSheetID == "draw" }

        XCTAssertTrue(model.handleKey(ActionKey(name: ",", isCommand: true)))

        XCTAssertEqual(host.settingsOpens, 1)
    }

    func testCommandCommaOpensSettingsWithNoSetup() async throws {
        try script("draw", toml: "title = 'Draw'", "printf 'item=own\\ntitle=Own\\n'")
        try await open(selecting: "draw")

        XCTAssertTrue(model.handleKey(ActionKey(name: ",", isCommand: true)))

        XCTAssertEqual(host.settingsOpens, 1)
        XCTAssertEqual(book.page, .general)
    }

    func testAPublishWithNoAccountOpensSettingsAtTheAccount() async throws {
        model.openSettings(at: .account)

        XCTAssertEqual(book.page, .account)
        XCTAssertEqual(host.settingsOpens, 1)
    }

    func testTheFactsLoadOnlyWhileTheWindowIsOpenAndEachLandingWaitsForThem() async throws {
        takeCalls()
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await model.reload()
        XCTAssertTrue(book.rows.all.isEmpty)

        model.openSettings(at: .row("cups/key.fill"))

        try await wait("the facts and the row") { self.book.page == .spotOf("cups") && self.book.target == "cups/key.fill" }
        book.closed()
        let rows = book.rows.all.count
        try script("mugs", toml: "title = 'Mugs'\n[actions.fill]\ntitle = 'Fill'", "")
        await model.spotsChanged()
        XCTAssertEqual(book.rows.all.count, rows)
    }

    func testASettingRowIsFoundInThePanelsSearchWithItsSpotAndOpensSettingsAtTheRow() async throws {
        takeCalls()
        try script("weather", toml: "title = 'Weather'\n[settings]\ncity = { type = 'text', title = 'Home city' }", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await wait("the rows") { self.book.searchRows.all.contains { $0.run == "weather/city" } }

        model.search("home city")

        let row = try XCTUnwrap(model.visible.first { $0.item?.run == "weather/city" })
        XCTAssertEqual(row.item?.title, "Home city")
        XCTAssertEqual(row.item?.place, "Weather")
        XCTAssertEqual(row.state.subtitle, "Settings › Weather")
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.item?.run == "weather/city" })
        model.runSelected()
        XCTAssertEqual(host.settingsOpens, 1)
        try await wait("Settings at the row") { self.book.page == .spotOf("weather") && self.book.target == "weather/city" }
    }

    func testSettingsItselfIsFoundInThePanelsSearch() async throws {
        takeCalls()
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await wait("the rows") { !self.book.searchRows.all.isEmpty }

        model.search("settings")

        let found = try XCTUnwrap(model.visible.firstIndex { $0.spot.id == SettingsBook.searchSpot.id && $0.item?.title == "Settings" })
        model.selected = found
        model.runSelected()
        XCTAssertEqual(host.settingsOpens, 1)
        XCTAssertEqual(book.page, .general)
    }
}
