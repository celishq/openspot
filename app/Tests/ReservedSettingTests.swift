import XCTest
@testable import OpenspotCore

final class ReservedSettingTests: XCTestCase {
    private func call(_ words: String...) -> CommandLineCall? {
        CommandLineCall(arguments: words, environment: [:])
    }

    func testASettingOfAPlaceOfASpotRunsTheCallThatDoesTheWork() {
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "menubar", "true")?.value as? SettingCall, .menuBar(spot: "notes", isShown: true))
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "window", "true")?.value as? SettingCall, .window(spot: "notes", isWindow: true))
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "enabled", "false")?.value as? SettingCall, .turn(spot: "notes", on: false))
        XCTAssertEqual(call("setting", "set", "--spot", "shelf", "float", "shake")?.value as? SettingCall, .key(spot: "shelf", act: .float, key: "shake"))
        XCTAssertEqual(call("setting", "set", "--spot", "move", "key.left", "ctrl+left")?.value as? SettingCall, .key(spot: "move", act: .command("left"), key: "ctrl+left"))
        XCTAssertEqual(call("setting", "set", "--spot", "move", "key.left")?.value as? SettingCall, .key(spot: "move", act: .command("left"), key: nil))
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "open", "ctrl+option+n")?.value as? SettingCall, .key(spot: "notes", act: .open, key: "ctrl+option+n"))
        XCTAssertEqual(call("setting", "set", "--spot", "notes", "open")?.value as? SettingCall, .key(spot: "notes", act: .open, key: nil))
    }

    func testASettingOfTheAppRunsTheCallThatDoesTheWork() {
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "login", "true")?.value as? SettingCall, .login(true))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "link", "false")?.value as? SettingCall, .link(false))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "careful", "true")?.value as? SettingCall, .careful(true))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "slow", "true")?.value as? SettingCall, .slow(true))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "theme", "Night")?.value as? SettingCall, .theme("Night"))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "panel-key", "ctrl+space")?.value as? SettingCall, .appKey(name: "panel-key", key: "ctrl+space"))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "fix-key", "ctrl+f")?.value as? SettingCall, .appKey(name: "fix-key", key: "ctrl+f"))
        XCTAssertEqual(call("setting", "set", "--spot", "openspot", "login", "yes")?.value as? CallFault, .refused("`login` takes `true` or `false`, such as `openspot setting set --spot openspot login true`."))
    }

    func testAnOwnValueOfASpotStaysAValue() {
        XCTAssertEqual(call("setting", "set", "--spot", "repos", "folder", "/tmp")?.value as? SettingCall, .set(spot: "repos", key: "folder", value: "/tmp"))
    }

    func testTheUseOfASettingIsTheUseOfTheCallThatItRuns() {
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "openspot", "login", "true"], of: "a")?.use, .app)
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "notes", "menubar", "true"], of: "a")?.use, .app)
        XCTAssertEqual(SpotUseCall(arguments: ["setting", "set", "--spot", "notes", "enabled", "true"], of: "a")?.use, .spots)
        XCTAssertNil(SpotUseCall(arguments: ["setting", "set", "folder", "/tmp"], of: "a"))
    }

    func testAFieldOfAHeaderCannotTakeAReservedKey() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reserved-\(UUID().uuidString).sh")
        try "#!/bin/sh\n".writeScript(to: url, toml: "title = 'Notes'\n\n[settings]\nmenubar = { type = 'text' }")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try SpotFile(file: url, id: "notes")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Notes has [settings] menubar, a key that Openspot keeps for the person. Give the setting another name.")
        }
    }
}
