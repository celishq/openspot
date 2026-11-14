import XCTest
@testable import OpenspotCore

final class ModifierTapTests: XCTestCase {
    func testALoneModifierLetGoInTimeIsATap() {
        var tap = ModifierTap()

        XCTAssertNil(tap.take(.option, at: 1))
        XCTAssertEqual(tap.take([], at: 1.2), .option)
        XCTAssertNil(tap.take(.command, at: 2))
        XCTAssertEqual(tap.take([], at: 2.1), .command)
    }

    func testAModifierHeldTooLongIsNoTap() {
        var tap = ModifierTap()

        _ = tap.take(.option, at: 1)

        XCTAssertNil(tap.take([], at: 1 + ModifierTap.limit + 0.1))
    }

    func testAModifierOfAShortcutOrAClickIsNoTapAndTheNextTapCounts() {
        var tap = ModifierTap()

        _ = tap.take(.option, at: 1)
        tap.spoil()
        XCTAssertNil(tap.take([], at: 1.1))

        _ = tap.take(.option, at: 2)
        _ = tap.take([.option, .shift], at: 2.05)
        _ = tap.take(.option, at: 2.1)
        XCTAssertNil(tap.take([], at: 2.15))

        _ = tap.take([.control, .option], at: 3)
        _ = tap.take(.option, at: 3.05)
        XCTAssertNil(tap.take([], at: 3.1))

        _ = tap.take(.option, at: 4)
        XCTAssertEqual(tap.take([], at: 4.1), .option)
    }

    func testATapIsAKeyThatTheFileKeeps() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-tap-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let config = Config(text: "[[keys]]\nspot = \"dictate\"\ncommand = \"dictate\"\nkey = \"option\"\n")

        XCTAssertEqual(config.keys, [GlobalKey(spot: "dictate", act: .command("dictate"), trigger: .tap(.option))])
        XCTAssertEqual(config.faults, [])

        try file.write(keys: config.keys)

        XCTAssertEqual(file.read().keys, config.keys)
        XCTAssertTrue(try String(contentsOf: file.url, encoding: .utf8).contains("key = \"option\""))
        XCTAssertEqual(Trigger.tap(.option).label, "⌥ Option")
        XCTAssertEqual(Trigger(text: "cmd")?.label, "⌘ Command")
        XCTAssertNil(Trigger(text: "option+shift"))
    }
}
