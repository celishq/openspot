import XCTest
@testable import OpenspotCore

/// Proves that `openspot setting set` sets the person's choices of a spot and of the app, as the calls that it took the
/// place of did, and that those calls name their new form.
final class ReservedSettingTests: XCTestCase {
    private func call(_ words: String...) -> CommandLineCall? {
        CommandLineCall(arguments: words, environment: [:])
    }

    func testASettingOfAPlaceOfASpotRunsTheCallThatDoesTheWork() {
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "menubar", "true"), .menuBar(id: "notes", isShown: true))
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "enabled", "false"), .spotTurn(ids: ["notes"], on: false))
        XCTAssertEqual(call("setting", "set", "--spot", "shelf", "float", "shake"), .keySet(spot: "shelf", act: .float, key: "shake"))
        XCTAssertEqual(call("setting", "set", "--spot", "move", "key.left", "ctrl+left"), .keySet(spot: "move", act: .command("left"), key: "ctrl+left"))
        XCTAssertEqual(call("setting", "set", "--spot", "move", "key.left"), .keySet(spot: "move", act: .command("left"), key: nil))
    }

    func testASettingOfTheAppRunsTheCallThatDoesTheWork() {
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "login", "true"), .appLogin(true))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "link", "false"), .appLink(false))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "careful", "true"), .appCareful(true))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "panel-key", "ctrl+space"), .appKeySet(name: "panel_key", key: "ctrl+space"))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "fix-key", "ctrl+f"), .appKeySet(name: "fix_key", key: "ctrl+f"))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "login", "yes"), .refused("`login` takes `true` or `false`, such as `openspot setting set --spot openspot login true`."))
    }

    func testAnOwnValueOfASpotStaysAValue() {
        XCTAssertEqual(call("setting", "set", "--spot", "repos", "folder", "/tmp"), .settingSet(spot: "repos", key: "folder", value: "/tmp"))
    }

    func testEachOldCallNamesItsNewForm() {
        XCTAssertEqual(call("menubar", "on", "notes"), .refused("`openspot menubar on notes` is now `openspot setting set --spot notes menubar true`."))
        XCTAssertEqual(call("spot", "off", "notes"), .refused("`openspot spot off notes` is now `openspot setting set --spot notes enabled false`."))
        XCTAssertEqual(call("app", "login", "on"), .refused("`openspot app login on` is now `openspot setting set --spot openspot login true`."))
        XCTAssertEqual(call("key", "set", "move", "left", "ctrl+left"), .refused("`openspot key set move left ctrl+left` is now `openspot setting set --spot move key.left ctrl+left`."))
        XCTAssertEqual(call("key", "set", "--panel", "ctrl+space"), .refused("`openspot key set --panel ctrl+space` is now `openspot setting set --spot openspot panel-key ctrl+space`."))
    }

    func testTheUseOfASettingIsTheUseOfTheCallThatItRuns() {
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "openspot", "login", "true"], of: "a")?.use, .app)
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "notes", "menubar", "true"], of: "a")?.use, .app)
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "notes", "enabled", "true"], of: "a")?.use, .spots)
        XCTAssertNil(SpotUseCall(arguments: ["setting", "set", "folder", "/tmp"], of: "a"))
    }

    func testAFieldOfAHeaderCannotTakeAReservedKey() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reserved-\(UUID().uuidString).sh")
        try "#!/bin/sh\n# title=Notes\n#\n# field=menubar\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try SpotFile(file: url, id: "notes")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Notes has field=menubar, a key that Openspot keeps for the person. Give the field another name.")
        }
    }
}
