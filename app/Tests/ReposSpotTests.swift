import XCTest
@testable import OpenspotCore

final class ReposSpotTests: SampleSpotsCase {
    private var repos: Spot {
        get throws {
            try example("Repos")
        }
    }

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
        XCTAssertEqual(try repos.settings.map(\.id), ["folder", "editor"])
        XCTAssertEqual(try repos.settings.map(\.title), ["Folder", "Default app"])
    }

    func testEnterOpensInTheFirstEditorUntilTheDefaultAppChanges() async throws {
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
            let change = try XCTUnwrap(first.actions.first { $0.title == "Change default app" })
            let form = try await repos.form(change, item: nil, timeout: 5)
            var draft = FormDraft(form: form)
            draft.choose(zed.path)
            _ = try await repos.submit(change, item: nil, draft: draft, timeout: 5)
            let then = repos.taking(try await repos.items(timeout: 5))

            XCTAssertNil(first.pickForm)
            XCTAssertEqual(first.openTitle, "Open in Cursor")
            XCTAssertEqual(opened, "-a \(cursor.path) \(item.run)\n")
            XCTAssertFalse(first.actions.contains { $0.title.hasPrefix("Use ") })
            XCTAssertEqual(change.scope, .spot)
            XCTAssertTrue(change.isForm)
            XCTAssertEqual(form.soleChoice?.options.map(\.title), ["Cursor", "Zed", "Finder"])
            XCTAssertEqual(try self.read("setting-editor", in: folder), zed.path)
            XCTAssertEqual(then.openTitle, "Open in Zed")
        }
    }

    func testTheEditorSettingAsksWithItsOptionsAsOneChoice() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let zed = folder.appendingPathComponent("Applications/Zed.app")
            try FileManager.default.createDirectory(at: zed, withIntermediateDirectories: true)
            let change = CommandAction(id: "editor", title: "Change editor", scope: .spot, after: .close)

            let form = try await repos.form(change, item: nil, timeout: 5)
            var draft = FormDraft(form: form)
            draft.choose(zed.path)
            _ = try await repos.submit(change, item: nil, draft: draft, timeout: 5)

            XCTAssertEqual(form.soleChoice?.options.map(\.title), ["Zed", "Finder"])
            XCTAssertEqual(try self.read("setting-editor", in: folder), zed.path)
        }
    }

    func testARepoWithAWebRemoteOffersToOpenItsPageOnItsHost() async throws {
        let repos = try repos
        try await withPrivateHome { folder in
            let code = folder.appendingPathComponent("code")
            let common = folder.appendingPathComponent("gits/common")
            try self.repo(code.appendingPathComponent("app"), head: "ref: refs/heads/main")
            try self.repo(code.appendingPathComponent("lab"), head: "ref: refs/heads/main")
            try self.repo(code.appendingPathComponent("local"), head: "ref: refs/heads/main")
            try self.repo(code.appendingPathComponent("own"), head: "ref: refs/heads/main", worktree: folder.appendingPathComponent("gits/common/worktrees/own"))
            try "[core]\n\tbare = false\n[remote \"upstream\"]\n\turl = https://example.com/fork.git\n[remote \"origin\"]\n\turl = git@github.com:me/app.git\n"
                .write(to: code.appendingPathComponent("app/.git/config"), atomically: true, encoding: .utf8)
            try "[remote \"origin\"]\n\turl=https://gitlab.com/team/lab.git\n".write(to: code.appendingPathComponent("lab/.git/config"), atomically: true, encoding: .utf8)
            try "[remote \"origin\"]\n\turl = /Users/me/backup.git\n".write(to: code.appendingPathComponent("local/.git/config"), atomically: true, encoding: .utf8)
            try "../..\n".write(to: common.appendingPathComponent("worktrees/own/commondir"), atomically: true, encoding: .utf8)
            try "[remote \"origin\"]\n\turl = ssh://git@git.example.com:2222/team/own.git\n".write(to: common.appendingPathComponent("config"), atomically: true, encoding: .utf8)
            try code.path.write(to: folder.appendingPathComponent("setting-folder"), atomically: true, encoding: .utf8)

            let output = try await repos.items(timeout: 5)
            let pages = repos.taking(output).actions.filter { $0.title.hasPrefix("Open on ") }
            let app = try XCTUnwrap(output.items.first { $0.title == "app" })
            let github = try XCTUnwrap(pages.first { $0.title == "Open on GitHub" })
            try await repos.perform(.action(github, item: app), timeout: 5)

            XCTAssertEqual(pages.map(\.title), ["Open on git.example.com", "Open on GitHub", "Open on GitLab"])
            XCTAssertEqual(output.items.map(\.title), ["app", "lab", "local", "own"])
            XCTAssertEqual(output.items.map { Set($0.hides ?? []) }, [
                Set(pages.map(\.id)).subtracting([github.id]),
                Set(pages.map(\.id)).subtracting([pages[2].id]),
                Set(pages.map(\.id)),
                Set(pages.map(\.id)).subtracting([pages[0].id])
            ])
            XCTAssertEqual(try self.read("opened", in: folder), "https://github.com/me/app\n")
        }
    }
}
