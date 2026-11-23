import XCTest
@testable import OpenspotCore

final class AppsSpotTests: SampleSpotsCase {
    private func apps() throws -> Spot {
        try XCTUnwrap(try scan.spots.first { $0.name == "Apps" })
    }

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

            let lines = try await apps.items(timeout: 60)

            let zed = try XCTUnwrap(lines.items.first { $0.run == app.path })
            let notes = try XCTUnwrap(lines.items.first { $0.title == "Notes" })
            XCTAssertEqual(lines.errors, [])
            XCTAssertTrue(zed.isOn)
            XCTAssertNil(zed.hides)
            XCTAssertEqual(notes.hides, ["quit", "uninstall"])
            XCTAssertEqual(apps.taking(lines).actions(for: zed).map(\.id), ["reveal", "quit", "uninstall"])
        }
    }

    func testAPressOfAnAppOpensIt() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            try await apps.handle(SpotItem(title: "Notes", run: "/System/Applications/Notes.app"), timeout: 60)

            XCTAssertEqual(try self.read("opened", in: folder), "/System/Applications/Notes.app\n")
        }
    }

    func testQuitAsksTheAppToQuitByItsBundleId() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: true)

            try await apps.handle("quit", [app.path], timeout: 60)

            let said = try String(contentsOf: folder.appendingPathComponent("osascript-args"), encoding: .utf8)
            XCTAssertEqual(said, "-e\ntell application id \"dev.zed.Zed\" to quit\n")
        }
    }

    func testDeleteShowsTheAppAndItsFilesTicksOnlyThoseOfItsBundleIdAndTrashesThoseThatStayChosen() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: false)
            let cache = try Self.library(folder, "Caches/dev.zed.Zed/db")
            let support = try Self.library(folder, "Application Support/Zed/settings.json")
            let preferences = try Self.library(folder, "Preferences/dev.zed.Zed.plist")
            _ = try Self.library(folder, "Caches/com.other.App/db")

            try await apps.handle("uninstall", [app.path], timeout: 60)
            let sheet = try await apps.items(input: "input.event=spot.change\n", timeout: 60)

            XCTAssertEqual(sheet.root?.value("title"), "Delete Zed")
            XCTAssertEqual(sheet.root?.value("detail"), "Move the app and its files to the Trash. A folder found only by the app's name waits for your tick.")
            XCTAssertEqual(sheet.parts.map(\.id), [])
            XCTAssertEqual(sheet.actions.map(\.id), ["cancel", "remove"])
            XCTAssertEqual(sheet.actions.map(\.key), [ActionKey(name: "escape"), ActionKey(name: "return", isCommand: true)])
            XCTAssertEqual(sheet.actions.map(\.scope), [.spot, .spot])
            XCTAssertEqual(Set(sheet.items.map(\.run)), [
                app.path, support.deletingLastPathComponent().path, cache.deletingLastPathComponent().path, preferences.path
            ])
            XCTAssertEqual(sheet.items.map(\.run), [app.path, support.deletingLastPathComponent().path, cache.deletingLastPathComponent().path, preferences.path])
            XCTAssertEqual(sheet.items.map(\.isOn), [true, false, true, true])
            XCTAssertEqual(sheet.pick, .stay)

            try await apps.handle(SpotItem(title: "dev.zed.Zed.plist", run: preferences.path), timeout: 60)
            let kept = try await apps.items(input: "input.event=spot.change\n", timeout: 60)
            XCTAssertEqual(kept.items.first { $0.run == preferences.path }?.isOn, false)
            try await apps.handle(SpotItem(title: "Zed", run: support.deletingLastPathComponent().path), timeout: 60)
            try await apps.handle("remove", timeout: 60)

            let said = try String(contentsOf: folder.appendingPathComponent("osascript-args"), encoding: .utf8)
            XCTAssertTrue(said.contains(app.path + "\n"))
            XCTAssertTrue(said.contains(cache.deletingLastPathComponent().path + "\n"))
            XCTAssertFalse(said.contains(preferences.path))
            XCTAssertTrue(said.contains(support.deletingLastPathComponent().path + "\n"))
            XCTAssertEqual(self.toasts(in: folder), ["Moved Zed and 2 of its files to the Trash"])
            let after = try await apps.items(input: "input.event=spot.change\n", timeout: 60)
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

            _ = try await apps.items(timeout: 60)
            let kept = try await apps.items(timeout: 60)
            try "/Applications/Alfa.app".write(toFile: folder.appendingPathComponent("found").path, atomically: true, encoding: .utf8)
            let stillKept = try await apps.items(timeout: 60)
            try "/Applications".write(toFile: changed, atomically: true, encoding: .utf8)
            let found = try await apps.items(timeout: 60)

            XCTAssertEqual(kept.items.map(\.title), ["Finder", "Zed"])
            XCTAssertEqual(stillKept.items.map(\.title), ["Finder", "Zed"])
            XCTAssertEqual(found.items.map(\.title), ["Alfa", "Finder"])
            XCTAssertEqual(try self.read("scans", in: folder), "scan\nscan\n")
        }
    }

    func testAReadWithKeptAppsStartsNoSortAndNoRm() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            let app = try Self.fakeApp(in: folder, running: true)
            try """
            #!/bin/sh
            case " $* " in
              *' -newer '*) ;;
              *) printf '%s\\n' '\(app.path)' /System/Applications/Notes.app ;;
            esac

            """.writeScript(to: folder.appendingPathComponent("tools/find"))
            _ = try await apps.items(timeout: 60)
            for tool in ["sort", "rm"] {
                try "#!/bin/sh\necho \(tool) >> '\(folder.path)/started'\nexec /usr/bin/\(tool) \"$@\"\n".writeScript(to: folder.appendingPathComponent("tools/\(tool)"))
            }

            let lines = try await apps.items(timeout: 60)

            XCTAssertEqual(lines.items.map(\.title), ["Finder", "Notes", "Zed"])
            XCTAssertEqual(lines.items.filter(\.isOn).map(\.title), ["Zed"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("started").path))
        }
    }

    func testASystemAppIsNeverDeleted() async throws {
        let apps = try apps()
        try await withPrivateHome { folder in
            _ = try Self.fakeApp(in: folder, running: false)

            do {
                try await apps.handle("uninstall", ["/System/Applications/Notes.app"], timeout: 60)
                XCTFail("A system app was taken for deletion")
            } catch SpotError.failed(_, let message) {
                XCTAssertEqual(message, "Notes is part of macOS, so it cannot be deleted.")
            }
        }
    }
}
