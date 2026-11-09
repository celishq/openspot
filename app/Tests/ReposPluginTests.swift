import XCTest
@testable import OpenspotCore

/// Proves the Repos example with its real script, a fake openspot command and a fake folder of repos.
final class ReposPluginTests: SamplePluginsCase {
    private var repos: Spot {
        get throws {
            let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
            return try XCTUnwrap(try PluginFolder(url: examples).scan().commands.first { $0.name == "Repos" })
        }
    }

    /// Makes a repo with this HEAD, or a worktree whose `.git` file points to its HEAD elsewhere.
    private func repo(_ path: URL, head: String, worktree: URL? = nil) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: path, withIntermediateDirectories: true)
        if let worktree {
            try manager.createDirectory(at: worktree, withIntermediateDirectories: true)
            try "gitdir: \(worktree.path)\n".write(to: path.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
            try "\(head)\n".write(to: worktree.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        } else {
            try manager.createDirectory(at: path.appendingPathComponent(".git"), withIntermediateDirectories: true)
            try "\(head)\n".write(to: path.appendingPathComponent(".git/HEAD"), atomically: true, encoding: .utf8)
        }
    }

    func testWithNoFolderItAsksForOneAndKeepsThePick() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            try folder.path.appending("/code").write(to: folder.appendingPathComponent("picked"), atomically: true, encoding: .utf8)

            let items = try await repos.items(timeout: 5).items
            try await repos.perform(.item(try XCTUnwrap(items.first)), timeout: 5)

            XCTAssertEqual(items.map(\.run), ["choose"])
            XCTAssertEqual(items.map(\.title), ["Choose the folder of your repos"])
            XCTAssertEqual(try self.read("setting-folder", in: folder), folder.path + "/code")
        }
    }

    func testItListsTheReposOneLevelInsideTheFolderWithTheirBranch() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let code = folder.appendingPathComponent("code")
            try self.repo(code.appendingPathComponent("app"), head: "ref: refs/heads/main")
            try self.repo(code.appendingPathComponent("site"), head: "ref: refs/heads/feature/new", worktree: folder.appendingPathComponent("gits/site"))
            try self.repo(code.appendingPathComponent("loose"), head: "9fceb02d0ae598e95dc970b74767f19372d61af8")
            try self.repo(code.appendingPathComponent("notes/inner"), head: "ref: refs/heads/main")
            try self.repo(code.appendingPathComponent(".hidden"), head: "ref: refs/heads/main")
            try code.path.write(to: folder.appendingPathComponent("setting-folder"), atomically: true, encoding: .utf8)

            let items = try await repos.items(timeout: 5).items

            XCTAssertEqual(items.map(\.title), ["app", "loose", "site"])
            XCTAssertEqual(items.map(\.subtitle), ["main", "9fceb02", "feature/new"])
            XCTAssertEqual(items.map(\.run), ["app", "loose", "site"].map { code.appendingPathComponent($0).path })
        }
    }

    func testAFolderWithNoRepoOffersToChooseAnother() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let empty = folder.appendingPathComponent("empty")
            try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
            try empty.path.write(to: folder.appendingPathComponent("setting-folder"), atomically: true, encoding: .utf8)

            let items = try await repos.items(timeout: 5).items

            XCTAssertEqual(items.map(\.run), ["choose"])
            XCTAssertEqual(items.map(\.subtitle), ["Choose another folder"])
        }
    }

    func testItNamesItsSettings() throws {
        XCTAssertEqual(try repos.settings, ["folder", "editor"])
    }

    func testEnterOpensInTheFirstEditorUntilAnotherIsTheDefault() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let code = folder.appendingPathComponent("code")
            let cursor = folder.appendingPathComponent("Applications/Cursor.app")
            let zed = folder.appendingPathComponent("Applications/Zed.app")
            try self.repo(code.appendingPathComponent("app"), head: "ref: refs/heads/main")
            try FileManager.default.createDirectory(at: cursor, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: zed, withIntermediateDirectories: true)
            try code.path.write(to: folder.appendingPathComponent("setting-folder"), atomically: true, encoding: .utf8)
            try "#!/bin/sh\necho \"$*\" > '\(folder.path)/opened'\n".writeScript(to: folder.appendingPathComponent("tools/open"))
            let item = SpotItem(title: "app", run: code.appendingPathComponent("app").path)

            let first = repos.taking(try await repos.items(timeout: 5))
            try await repos.perform(.item(item), timeout: 5)
            let opened = try self.read("opened", in: folder)
            let use = try XCTUnwrap(first.actions.first { $0.title == "Use Zed by default" })
            try await repos.perform(.action(use, item: nil), timeout: 5)
            let then = repos.taking(try await repos.items(timeout: 5))

            XCTAssertNil(first.pickForm)
            XCTAssertEqual(first.primary, "Open in Cursor")
            XCTAssertEqual(first.actions.map(\.title).filter { $0.hasPrefix("Use ") }, ["Use Zed by default", "Use Finder by default"])
            XCTAssertEqual(use.scope, .command)
            XCTAssertEqual(opened, "-a \(cursor.path) \(item.run)\n")
            XCTAssertEqual(try self.read("setting-editor", in: folder), zed.path)
            XCTAssertEqual(then.primary, "Open in Zed")
            XCTAssertEqual(then.actions.map(\.title).filter { $0.hasPrefix("Use ") }, ["Use Cursor by default", "Use Finder by default"])
        }
    }

    func testTheEditorSettingAsksWithItsOptionsAsOneChoice() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let zed = folder.appendingPathComponent("Applications/Zed.app")
            try FileManager.default.createDirectory(at: zed, withIntermediateDirectories: true)
            let change = CommandAction(id: "editor", title: "Change editor", scope: .command, after: .close)

            let form = try await repos.form(change, item: nil, timeout: 5)
            var draft = FormDraft(form: form)
            draft.choose(zed.path)
            _ = try await repos.submit(change, item: nil, draft: draft, timeout: 5)

            XCTAssertEqual(form.soleChoice?.options.map(\.title), ["Zed", "Finder"])
            XCTAssertEqual(try self.read("setting-editor", in: folder), zed.path)
        }
    }
}
