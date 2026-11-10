import XCTest
@testable import OpenspotCore

/// Proves the Shortcuts spot with its real script in a private home and a fake `shortcuts` command.
final class ShortcutsPluginTests: SamplePluginsCase {
    private func shortcuts() throws -> Spot {
        try XCTUnwrap(try scan.commands.first { $0.name == "Shortcuts" })
    }

    /// Puts a fake `shortcuts` on the path. It lists one folder, and a run or a view writes its arguments to `shortcuts-args`,
    /// one on each line. A run gives the file `result` as its result, and fails when the file `fail` is there.
    private static func fakeShortcuts(in folder: URL) throws {
        let script = """
        #!/bin/sh
        case "$1 $2 $3" in
          'list --folders ') echo Media ;;
          'list --folder-name Media') echo 'Video to audio' ;;
          'list --folder-name none') printf '%s\\n' 'Say \\ "hi" (now)' 'Take a break' ;;
          run*|view*)
            printf '%s\\n' "$@" > '\(folder.path)/shortcuts-args'
            [ -f '\(folder.path)/fail' ] && { echo 'Error: The operation could not be completed.' >&2; exit 1; }
            out=''
            previous=''
            for a; do [ "$previous" = -o ] && out=$a; previous=$a; done
            [ -n "$out" ] && [ -f '\(folder.path)/result' ] && cp '\(folder.path)/result' "$out"
            ;;
        esac
        exit 0

        """
        try script.writeScript(to: folder.appendingPathComponent("tools/shortcuts"))
    }

    private func shortcut(_ title: String, of shortcuts: Spot) async throws -> SpotItem {
        let lines = try await shortcuts.items(timeout: 10)
        return try XCTUnwrap(lines.items.first { $0.title == title })
    }

    private func runArguments(in folder: URL) throws -> [String] {
        try read("shortcuts-args", in: folder).split(separator: "\n").map(String.init)
    }

    func testEachShortcutIsARowUnderItsFolderWithTheIconOfShortcuts() async throws {
        let shortcuts = try shortcuts()
        XCTAssertEqual(shortcuts.file, "/System/Applications/Shortcuts.app")
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)

            let lines = try await shortcuts.items(timeout: 10)

            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.title), ["Say \\ \"hi\" (now)", "Take a break", "Video to audio"])
            XCTAssertEqual(lines.items.map(\.parent), [nil, nil, "Media"])
            XCTAssertEqual(Set(lines.items.map(\.iconFile)), ["/System/Applications/Shortcuts.app"])
        }
    }

    func testEnterRunsTheShortcutAndCopiesItsText() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            try "18°C, sunny\nWind 3 m/s".write(to: folder.appendingPathComponent("result"), atomically: true, encoding: .utf8)
            let row = try await shortcut("Say \\ \"hi\" (now)", of: shortcuts)

            let toast = try await shortcuts.perform(.item(row), timeout: 10)

            let arguments = try runArguments(in: folder)
            XCTAssertEqual(Array(arguments.prefix(3)), ["run", "Say \\ \"hi\" (now)", "-o"])
            XCTAssertFalse(arguments.contains("-i"))
            XCTAssertEqual(try read("clipboard", in: folder), "18°C, sunny\nWind 3 m/s")
            XCTAssertEqual(toast, "Copied the result of Say \\ \"hi\" (now).")
        }
    }

    func testAShortcutWithNoResultSaysThatItRan() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            let row = try await shortcut("Take a break", of: shortcuts)

            let toast = try await shortcuts.perform(.item(row), timeout: 10)

            XCTAssertEqual(toast, "Ran Take a break.")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
        }
    }

    func testAFileResultIsCopiedAsAFileOfItsKind() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            try "#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(folder.path)/openspot-args'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
            try png.write(to: folder.appendingPathComponent("result"))
            let row = try await shortcut("Video to audio", of: shortcuts)

            let toast = try await shortcuts.perform(.item(row), timeout: 10)

            let copy = try read("openspot-args", in: folder).split(separator: "\n").map(String.init)
            XCTAssertEqual(Array(copy.prefix(2)), ["clipboard", "copy"])
            let file = try XCTUnwrap(copy.last)
            XCTAssertEqual(URL(fileURLWithPath: file).lastPathComponent, "Video to audio.png")
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: file)), png)
            XCTAssertEqual(toast, "Copied the result of Video to audio.")
        }
    }

    func testCommandEnterRunsTheShortcutWithTheCopiedText() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            try "hello there".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)
            let lines = try await shortcuts.items(timeout: 10)
            let row = try XCTUnwrap(lines.items.first { $0.title == "Take a break" })
            let action = try XCTUnwrap(lines.actions.first { $0.id == "clipboard" })
            XCTAssertEqual(action.title, "Run with clipboard")
            XCTAssertEqual(action.key, ActionKey(name: "return", isCommand: true))

            try await shortcuts.perform(.action(action, item: row), timeout: 10)

            let arguments = try runArguments(in: folder)
            XCTAssertEqual(Array(arguments.prefix(3)), ["run", "Take a break", "-i"])
            XCTAssertEqual(try String(contentsOfFile: arguments[3], encoding: .utf8), "hello there")
        }
    }

    func testDroppedFilesAreTheInputOfTheNextPickOnly() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            let files = ["a.mov", "b c.mov"].map { folder.appendingPathComponent($0).path }

            try await shortcuts.perform(.drop(paths: files), timeout: 10)
            let sheet = try await shortcuts.items(timeout: 10)
            let row = try XCTUnwrap(sheet.items.first { $0.title == "Video to audio" })
            try await shortcuts.perform(.item(row), timeout: 10)
            let first = try runArguments(in: folder)
            let after = try await shortcuts.items(timeout: 10)
            try await shortcuts.perform(.item(row), timeout: 10)
            let second = try runArguments(in: folder)

            XCTAssertEqual(sheet.summary?.value("title"), "Run with 2 files")
            XCTAssertEqual(sheet.actions.first { $0.id == "cancel" }?.key, ActionKey(name: "escape"))
            XCTAssertEqual(Array(first.prefix(6)), ["run", "Video to audio", "-i", files[0], "-i", files[1]])
            XCTAssertNil(after.summary?.value("title"))
            XCTAssertFalse(second.contains("-i"))
        }
    }

    func testOpeningThePanelOrCancelDropsTheFilesThatNoPickTook() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            let file = folder.appendingPathComponent("a.mov").path

            try await shortcuts.perform(.drop(paths: [file]), timeout: 10)
            let dropped = try await shortcuts.items(timeout: 10)
            setenv("OPENSPOT_REASON", "panel", 1)
            let reopened = try await shortcuts.items(timeout: 10)
            unsetenv("OPENSPOT_REASON")
            try await shortcuts.perform(.drop(paths: [file]), timeout: 10)
            try await shortcuts.perform(.press("cancel"), timeout: 10)
            let cancelled = try await shortcuts.items(timeout: 10)

            XCTAssertEqual(dropped.summary?.value("title"), "Run with a.mov")
            XCTAssertNil(reopened.summary?.value("title"))
            XCTAssertNil(cancelled.summary?.value("title"))
        }
    }

    func testOpenInShortcutsShowsTheShortcutThere() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            let lines = try await shortcuts.items(timeout: 10)
            let row = try XCTUnwrap(lines.items.first { $0.title == "Video to audio" })
            let action = try XCTUnwrap(lines.actions.first { $0.id == "edit" })
            XCTAssertEqual(action.title, "Open in Shortcuts")
            XCTAssertEqual(action.key, ActionKey(name: "e", isCommand: true))

            try await shortcuts.perform(.action(action, item: row), timeout: 10)

            XCTAssertEqual(try runArguments(in: folder), ["view", "Video to audio"])
        }
    }

    func testAFailedRunSaysSoAndLinksTheShortcutInShortcuts() async throws {
        let shortcuts = try shortcuts()
        try await withPrivateHome { folder in
            try Self.fakeShortcuts(in: folder)
            FileManager.default.createFile(atPath: folder.appendingPathComponent("fail").path, contents: Data())
            let row = try await shortcut("Take a break", of: shortcuts)

            do {
                try await shortcuts.perform(.item(row), timeout: 10)
                XCTFail("A failed run passed")
            } catch PluginError.failedWithFix(_, let message, let link) {
                XCTAssertEqual(message, "Take a break stopped before it finished. Open it in Shortcuts to see which step failed.")
                XCTAssertEqual(link.absoluteString, "shortcuts://open-shortcut?name=Take%20a%20break")
            }
        }
    }
}
