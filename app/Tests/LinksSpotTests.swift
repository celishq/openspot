import XCTest
@testable import OpenspotCore

final class LinksSpotTests: SampleSpotsCase {
    func testLinksAndAppsJoinTheMainSearch() throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        let apps = try XCTUnwrap(try scan.spots.first { $0.name == "Apps" })

        XCTAssertTrue(links.isGlobal)
        XCTAssertTrue(apps.isGlobal)
    }

    func testAFixableFailureLinksItsFix() throws {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-fix-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let accessibility = "link=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n"
        let refusal = "Openspot cannot move the window. Allow it in Accessibility, then press the key again."
        try "#!/bin/sh\nprintf '\(accessibility)'\necho '\(refusal)' >&2\nexit 1\n".writeScript(to: tools.appendingPathComponent("openspot"))

        for (script, arguments, fix, message) in [
            ("windows.sh", ["left"], accessibility, refusal + "\n")
        ] {
            let process = Process()
            let out = Pipe()
            let errors = Pipe()
            process.executableURL = spots.appendingPathComponent(script.inSpotFolder)
            process.arguments = arguments
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path, "OPENSPOT_DATA": folder.path]
            process.standardOutput = out
            process.standardError = errors
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let said = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            XCTAssertEqual(process.terminationStatus, 1, script)
            XCTAssertEqual(text, fix, script)
            XCTAssertEqual(said, message, script)
        }
    }

    func testLinksShowsTheIconASiteNamesOnItsPage() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://icons.test/deep/page", in: links)
            let expected = folder.appendingPathComponent(".config/openspot/data/links/icons/icons.test.png").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: expected) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let items = try await links.items(timeout: 60).items
            let site = items.first { $0.title == "Site" }

            XCTAssertEqual(site?.image, expected)
            XCTAssertEqual(site?.subtitle, "icons.test")
        }
    }

    func testLinksKeepsItsGlyphAndDoesNotAskAgainWhenASiteHasNoIcon() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://none.test", in: links)
            let marker = folder.appendingPathComponent(".config/openspot/data/links/icons/none.test.none").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: marker) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let before = try self.read("fetched", in: folder)
            let items = try await links.items(timeout: 60).items
            let site = items.first { $0.title == "Site" }
            try await Task.sleep(nanoseconds: 500_000_000)

            XCTAssertNil(site?.image)
            XCTAssertEqual(site?.symbol, "link")
            XCTAssertEqual(try self.read("fetched", in: folder), before)
        }
    }

    func testAReadStartsOnlyJqAndAsksTheWebNothing() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let data = folder.appendingPathComponent(".config/openspot/data/links")
            try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
            try #"[{"id":"1","title":"Site","url":"https://icons.test"}]"#.write(to: data.appendingPathComponent("links.json"), atomically: true, encoding: .utf8)
            for tool in ["cat", "ls"] {
                try "#!/bin/sh\necho \(tool) >> '\(folder.path)/started'\nexec /bin/\(tool) \"$@\"\n".writeScript(to: folder.appendingPathComponent("tools/\(tool)"))
            }

            let items = try await links.items(timeout: 60).items
            try await self.readsEnded(of: links)

            XCTAssertEqual(items.map(\.title), ["Site"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("started").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("fetched").path))
        }
    }

    func testASaveTriesAgainASiteThatHadNoIconAWeekAgo() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let data = folder.appendingPathComponent(".config/openspot/data/links")
            let icons = data.appendingPathComponent("icons")
            try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
            try #"[{"id":"1","title":"Site","url":"https://icons.test"}]"#.write(to: data.appendingPathComponent("links.json"), atomically: true, encoding: .utf8)
            let marker = icons.appendingPathComponent("icons.test.none")
            FileManager.default.createFile(atPath: marker.path, contents: Data())
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-8 * 86400)], ofItemAtPath: marker.path)

            try await self.savedLink("https://none.test", in: links)

            XCTAssertFalse(links.read?.has(.event(SpotEvent.appLaunch)) == true)
            XCTAssertTrue(FileManager.default.fileExists(atPath: icons.appendingPathComponent("icons.test.png").path))
        }
    }

    func testASaveFetchesTheIconInsideItsCall() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let curl = folder.appendingPathComponent("tools/curl")
            let fake = try String(contentsOf: curl, encoding: .utf8)
            try fake.replacingOccurrences(of: "#!/bin/sh\n", with: "#!/bin/sh\n/bin/sleep 1\n").writeScript(to: curl)

            try await self.savedLink("https://icons.test", in: links)

            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".config/openspot/data/links/icons/icons.test.png").path))
        }
    }

    func testAStopInTheMiddleOfADownloadLeavesNoPartOfTheIcon() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try """
            #!/bin/sh
            out=""
            for a; do [ "$previous" = "-o" ] && out=$a; previous=$a; url=$a; done
            case "$url" in
              https://slow.test/) echo '<link rel="icon" href="/a.png">' ;;
              *) printf part > "$out"; exec /bin/sleep 600 ;;
            esac
            """.writeScript(to: folder.appendingPathComponent("tools/curl"))
            let icons = folder.appendingPathComponent(".config/openspot/data/links/icons")
            let parts = { (try? FileManager.default.contentsOfDirectory(atPath: icons.path))?.filter { $0.hasPrefix(".") } ?? [] }
            let save = ScriptProcess(url: links.url, arguments: ["new"], mode: .once(input: "title=Slow\nurl=https://slow.test\n"), stopPause: 0.5, dataName: links.dataName, base: TestEnvironment.values)
            let frames = save.start()

            try await self.wait("the part of the icon") { !parts().isEmpty }
            save.stop()
            for try await _ in frames {}
            try await self.wait("the end of the save") { !save.isRunning }

            XCTAssertEqual(parts(), [])
            XCTAssertFalse(FileManager.default.fileExists(atPath: icons.appendingPathComponent("slow.test.png").path))
        }
    }

    private func readsEnded(of spot: Spot) async throws {
        for _ in 0..<3000 {
            let pgrep = Process()
            pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            pgrep.arguments = ["-f", "\(spot.url.path) read"]
            pgrep.standardOutput = FileHandle.nullDevice
            try pgrep.run()
            pgrep.waitUntilExit()
            if pgrep.terminationStatus != 0 { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("a read of \(spot.name) still runs")
    }

    func testAnEditFetchesTheIconOfItsSite() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let edit = try await action("edit", of: links)
            let data = folder.appendingPathComponent(".config/openspot/data/links")
            try #"[{"id":"1","title":"Site","url":"https://none.test"}]"#.write(to: data.appendingPathComponent("links.json"), atomically: true, encoding: .utf8)
            let row = SpotItem(title: "Site", run: "1")
            var draft = FormDraft(form: try await links.form(edit, item: row, timeout: 60))
            draft.set("https://icons.test", for: "url")
            let expected = data.appendingPathComponent("icons/icons.test.png").path

            _ = try await links.submit(edit, item: row, draft: draft, timeout: 60)
            for _ in 0..<50 where !FileManager.default.fileExists(atPath: expected) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            XCTAssertTrue(FileManager.default.fileExists(atPath: expected))
        }
    }

    func testLinksCompletesALinkAndOpensAndCopiesIt() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let new = try await action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 60))
            draft.set("Docs", for: "title")
            draft.set(" github.com/a/b ", for: "url")
            _ = try await links.submit(new, item: nil, draft: draft, timeout: 60)

            let saved = try await links.items(timeout: 60).items
            let item = try XCTUnwrap(saved.first { $0.title == "Docs" })
            XCTAssertEqual(item.subtitle, "github.com")
            XCTAssertEqual(item.hides, ["reveal"])

            try await links.perform(.item(item), timeout: 60)
            XCTAssertEqual(try self.read("opened", in: folder), "https://github.com/a/b\n")

            try await links.perform(.action(try await self.action("copy", of: links), item: item), timeout: 60)
            XCTAssertEqual(try self.read("clipboard", in: folder), "https://github.com/a/b")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testLinksRefusesALinkWithSpaces() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { _ in
            let new = try await action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 60))
            draft.set("Bad", for: "title")
            draft.set("not a link", for: "url")
            do {
                _ = try await links.submit(new, item: nil, draft: draft, timeout: 60)
                XCTFail("expected a failure")
            } catch let error as SpotError {
                XCTAssertEqual(error.reason, "Enter a link with no spaces, or a path.")
            }
        }
    }

    func testLinksStartWithTheFolderShortcuts() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let items = try await links.items(timeout: 60).items

            XCTAssertEqual(items.map(\.title), ["Downloads", "Screenshots"])
            XCTAssertEqual(items.first?.subtitle, "~/Downloads")
            XCTAssertEqual(items.first?.iconFile, folder.path + "/Downloads")
            XCTAssertNil(items.first?.hides)
        }
    }

    func testLinksKeepsItsListAfterEachShortcutIsDeleted() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { _ in
            let delete = try await self.action("delete", of: links)
            for item in try await links.items(timeout: 60).items {
                try await links.perform(.action(delete, item: item), timeout: 60)
            }

            let items = try await links.items(timeout: 60).items

            XCTAssertEqual(items, [])
        }
    }

    func testLinksOpensAFolderAndKeepsSpacesInItsPath() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let place = folder.appendingPathComponent("My Work")
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            let new = try await self.action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 60))
            draft.set("Work", for: "title")
            draft.set("~/My Work", for: "url")
            let run = try await links.submit(new, item: nil, draft: draft, timeout: 60)
            let all = try await links.items(timeout: 60).items
            let item = try XCTUnwrap(all.first { $0.run == run })

            try await links.perform(.item(item), timeout: 60)

            XCTAssertEqual(item.iconFile, place.path)
            XCTAssertEqual(try self.read("opened", in: folder), place.path + "\n")
        }
    }

    func testLinksSaysWhenAFolderIsGone() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let downloads = try await links.items(timeout: 60).items.first { $0.title == "Downloads" }
            do {
                try await links.perform(.item(try XCTUnwrap(downloads)), timeout: 60)
                XCTFail("expected a failure")
            } catch let error as SpotError {
                XCTAssertEqual(error.reason, "Openspot cannot find \(folder.path)/Downloads.")
            }
        }
    }

    func testLinksShowsAFolderInFinder() async throws {
        let links = try XCTUnwrap(try scan.spots.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
            let downloads = try await links.items(timeout: 60).items.first { $0.title == "Downloads" }

            try await links.perform(.action(try await self.action("reveal", of: links), item: downloads), timeout: 60)

            XCTAssertEqual(try self.read("opened", in: folder), "-R\n")
        }
    }
}
