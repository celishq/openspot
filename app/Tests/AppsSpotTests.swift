import XCTest
@testable import OpenspotCore

final class AppsSpotTests: SampleSpotsCase {
    private func apps() throws -> Spot {
        try XCTUnwrap(try scan.spots.first { $0.name == "Apps" })
    }

    /// Makes an app with a bundle id in a private home, and fake `find`, `ps` and `osascript`. The fake `osascript` writes
    /// its arguments to `osascript-args`, one on each line.
    private static func fakeApp(in folder: URL, running: Bool) throws -> URL {
        let app = folder.appendingPathComponent("Applications/Zed.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.zed.Zed</string></dict></plist>
        """.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\nprintf '%s\\n' '\(app.path)' /System/Applications/Notes.app\n".writeScript(to: tools.appendingPathComponent("find"))
        let live = running ? "\(app.path)/Contents/MacOS/zed" : "/usr/sbin/cfprefsd"
        try "#!/bin/sh\nprintf '%s\\n' '\(live)' /usr/libexec/logd\n".writeScript(to: tools.appendingPathComponent("ps"))
        try "#!/bin/sh\nprintf '%s\\n' \"$@\" >> '\(folder.path)/osascript-args'\n".writeScript(to: tools.appendingPathComponent("osascript"))
        return app
    }

    private static func library(_ folder: URL, _ path: String) throws -> URL {
        let url = folder.appendingPathComponent("Library").appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
        return url
    }

    func testTheSpotShowsTheIconOfTheAppsApp() throws {
        XCTAssertEqual(try apps().file, "/System/Applications/Apps.app")
    }

    func testARunningAppShowsADotAndOffersQuitAndASystemAppCannotBeDeleted() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: true)

            let lines = try await apps.items(timeout: 10)

            let zed = try XCTUnwrap(lines.items.first { $0.run == app.path })
            let notes = try XCTUnwrap(lines.items.first { $0.title == "Notes" })
            XCTAssertEqual(lines.errors, [])
            XCTAssertTrue(zed.isOn)
            XCTAssertNil(zed.hides)
            XCTAssertEqual(notes.hides, ["quit", "uninstall"])
            XCTAssertEqual(apps.taking(lines).actions(for: zed).map(\.id), ["reveal", "quit", "uninstall"])
        }
    }

    func testQuitAsksTheAppToQuitByItsBundleId() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: true)

            try await apps.perform(SpotAction(arguments: ["quit", app.path]), timeout: 10)

            let said = try String(contentsOf: folder.appendingPathComponent("osascript-args"), encoding: .utf8)
            XCTAssertEqual(said, "-e\ntell application id \"dev.zed.Zed\" to quit\n")
        }
    }

    func testDeleteShowsTheAppAndItsFilesAndTrashesOnlyThoseThatStayChosen() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: false)
            let cache = try Self.library(folder, "Caches/dev.zed.Zed/db")
            let support = try Self.library(folder, "Application Support/Zed/settings.json")
            let preferences = try Self.library(folder, "Preferences/dev.zed.Zed.plist")
            _ = try Self.library(folder, "Caches/com.other.App/db")
            setenv("OPENSPOT_REASON", "spot.change", 1)
            defer { unsetenv("OPENSPOT_REASON") }

            try await apps.perform(SpotAction(arguments: ["uninstall", app.path]), timeout: 10)
            let sheet = try await apps.items(timeout: 10)

            XCTAssertEqual(sheet.summary?.value("title"), "Delete Zed")
            XCTAssertEqual(sheet.parts.map(\.id), [])
            XCTAssertEqual(sheet.actions.map(\.id), ["cancel", "remove"])
            XCTAssertEqual(sheet.actions.map(\.key), [ActionKey(name: "escape"), ActionKey(name: "return", isCommand: true)])
            XCTAssertEqual(sheet.actions.map(\.scope), [.spot, .spot])
            XCTAssertEqual(Set(sheet.items.map(\.run)), [
                app.path, support.deletingLastPathComponent().path, cache.deletingLastPathComponent().path, preferences.path
            ])
            XCTAssertEqual(sheet.items.map(\.isOn), Array(repeating: true, count: 4))
            XCTAssertEqual(sheet.pick, .stay)

            try await apps.perform(.item(SpotItem(title: "dev.zed.Zed.plist", run: preferences.path)), timeout: 10)
            let kept = try await apps.items(timeout: 10)
            XCTAssertEqual(kept.items.first { $0.run == preferences.path }?.isOn, false)
            let toast = try await apps.perform(.press("remove"), timeout: 10)

            let said = try String(contentsOf: folder.appendingPathComponent("osascript-args"), encoding: .utf8)
            XCTAssertTrue(said.contains(app.path + "\n"))
            XCTAssertTrue(said.contains(cache.deletingLastPathComponent().path + "\n"))
            XCTAssertFalse(said.contains(preferences.path))
            XCTAssertEqual(toast, "Moved Zed and 2 of its files to the Trash")
            let after = try await apps.items(timeout: 10)
            XCTAssertTrue(after.parts.isEmpty)
        }
    }

    func testAReadFindsTheAppsAgainOnlyWhenAFolderOfAppsChanged() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: false)
            let scans = folder.appendingPathComponent("scans").path
            let changed = folder.appendingPathComponent("changed").path
            try """
            #!/bin/sh
            case " $* " in
              *' -newer '*) cat '\(changed)' 2>/dev/null ;;
              *) echo scan >> '\(scans)'; printf '%s\\n' "$(cat '\(folder.path)/found' 2>/dev/null || echo '\(app.path)')" ;;
            esac

            """.writeScript(to: folder.appendingPathComponent("tools/find"))

            _ = try await apps.items(timeout: 10)
            let kept = try await apps.items(timeout: 10)
            try "/Applications/Alfa.app".write(toFile: folder.appendingPathComponent("found").path, atomically: true, encoding: .utf8)
            let stillKept = try await apps.items(timeout: 10)
            try "/Applications".write(toFile: changed, atomically: true, encoding: .utf8)
            let found = try await apps.items(timeout: 10)

            XCTAssertEqual(kept.items.map(\.title), ["Finder", "Zed"])
            XCTAssertEqual(stillKept.items.map(\.title), ["Finder", "Zed"])
            XCTAssertEqual(found.items.map(\.title), ["Alfa", "Finder"])
            XCTAssertEqual(try self.read("scans", in: folder), "scan\nscan\n")
        }
    }

    func testASystemAppIsNeverDeleted() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            _ = try Self.fakeApp(in: folder, running: false)

            do {
                try await apps.perform(SpotAction(arguments: ["uninstall", "/System/Applications/Notes.app"]), timeout: 10)
                XCTFail("A system app was taken for deletion")
            } catch SpotError.failed(_, let message) {
                XCTAssertEqual(message, "Notes is part of macOS, so it cannot be deleted.")
            }
        }
    }
}
