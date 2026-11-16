import XCTest
@testable import OpenspotCore

final class SystemKeysTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ keys: [String: (enabled: Bool, parameters: [Int])]) throws -> SystemKeys {
        var entries: [String: Any] = [:]
        for (id, key) in keys {
            entries[id] = ["enabled": key.enabled, "value": ["parameters": key.parameters, "type": "standard"]] as [String: Any]
        }
        let data = try PropertyListSerialization.data(fromPropertyList: ["AppleSymbolicHotKeys": entries], format: .binary, options: 0)
        let url = folder.appendingPathComponent("com.apple.symbolichotkeys.plist")
        try data.write(to: url)
        return SystemKeys(url: url)
    }

    func testAnEnabledKeyIsTakenWithWhatItDoes() throws {
        let keys = try write(["64": (true, [32, 49, 1048576])])
        XCTAssertEqual(keys.read(), [TakenKey(shortcut: Shortcut(code: 49, modifiers: .command)!, use: "opens Spotlight")])
    }

    func testTheInputSourceKeysAndFinderSearchSayWhatTheyDo() throws {
        let keys = try write([
            "60": (true, [32, 49, 262144]),
            "61": (true, [32, 49, 786432]),
            "65": (true, [32, 49, 1572864]),
        ])
        XCTAssertEqual(keys.read(), [
            TakenKey(shortcut: Shortcut(code: 49, modifiers: .control)!, use: "switches to the previous input source"),
            TakenKey(shortcut: Shortcut(code: 49, modifiers: [.control, .option])!, use: "switches to the next input source"),
            TakenKey(shortcut: Shortcut(code: 49, modifiers: [.option, .command])!, use: "opens a Finder search"),
        ])
    }

    func testADisabledKeyAnUnknownIdAndAnEntryWithNoKeyAreNotTaken() throws {
        let keys = try write([
            "64": (false, [32, 49, 1048576]),
            "999": (true, [32, 49, 1048576]),
            "60": (true, [65535, 65535, 0]),
        ])
        XCTAssertEqual(keys.read(), [])
    }

    func testAMissingFileTakesNoKey() {
        XCTAssertEqual(SystemKeys(url: folder.appendingPathComponent("none.plist")).read(), [])
    }

    func testStandardPointsAtTheSymbolicHotKeysFile() {
        XCTAssertEqual(SystemKeys.standard(home: folder).url, folder.appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist"))
    }
}
