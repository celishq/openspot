import XCTest
@testable import OpenspotCore

final class RaycastDataImportTests: XCTestCase {
    private var root: URL!
    private var export: URL!

    private var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
    }

    private var config: URL {
        root.appendingPathComponent(".config/openspot")
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": config.path, "OPENSPOT_SPOTS": config.appendingPathComponent("spots").path, "OPENSPOT_CORE": repoSpots.path, "HOME": root.path, "PWD": root.path, "PATH": "/usr/bin:/bin",
         "OPENSPOT_SH": repoSpots.deletingLastPathComponent().appendingPathComponent("app/Shell/openspot.sh").path]
    }

    override func setUpWithError() throws {
        root = try temporaryFolder()
        try FileManager.default.createDirectory(at: config.appendingPathComponent("spots"), withIntermediateDirectories: true)
        export = root.appendingPathComponent("Raycast 2026-11-18.rayconfig")
        try RaycastExport.file(RaycastExport.testPayload, passphrase: "openspot-test").write(to: export)
    }

    private func answer(_ arguments: [String], passphrase: String = "openspot-test") async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: Mac(), places: .test(environment), rates: .offline).work(for: call, request: .test(arguments, in: environment), input: { passphrase + "\n" }))
        return await work()
    }

    private func rows(_ answer: CommandAnswer) -> [String] {
        TextBlock.blocks(in: answer.output).compactMap { block in block.value("row").map { "\($0) \(block.value("outcome") ?? "") \(block.value("detail") ?? "")" } }
    }

    private func data(_ spot: String) -> String {
        (try? String(contentsOf: config.appendingPathComponent("data/\(spot)/\(spot).json"), encoding: .utf8)) ?? ""
    }

    func testAnImportAddsTheQuicklinksToLinksAndTheSnippetsToSnippetsAndNamesWhatItSkips() async throws {
        let answer = try await answer(["import", "rayconfig", export.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(rows(answer), [
            "links added Added 1 link to Links",
            "snippets added Added 1 snippet to Snippets",
            "hotkeys skipped Openspot has no place for them yet",
            "aliases skipped Openspot has no place for them yet"
        ])
        XCTAssertTrue(data("links").contains(#""url":"https://www.google.com/search?q={query}""#), data("links"))
        XCTAssertTrue(data("snippets").contains(#""keyword":";mail""#), data("snippets"))
    }

    func testADryRunCountsAndChangesNothing() async throws {
        let answer = try await answer(["import", "rayconfig", export.path, "--dry-run"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(rows(answer).prefix(2), ["links added 2 to add to Links", "snippets added 1 to add to Snippets"])
        XCTAssertEqual(data("links"), "")
        XCTAssertEqual(data("snippets"), "")
    }

    func testAWrongPassphraseFailsWithWhereToFindIt() async throws {
        let answer = try await answer(["import", "rayconfig", export.path], passphrase: "wrong-pass")

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("Wrong passphrase."), answer.errors)
        XCTAssertEqual(data("links"), "")
    }

    func testAnExportOpenedOnceImportsWithNoPassphrase() async throws {
        let dry = try await answer(["import", "rayconfig", export.path, "--dry-run"])
        let answer = try await answer(["import", "rayconfig", export.path], passphrase: "")

        XCTAssertEqual(dry.code, 0, dry.errors)
        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(data("links").contains("Google Search"), data("links"))
    }

    func testAnExportNotOpenedYetAsksForItsPassphrase() async throws {
        let answer = try await answer(["import", "rayconfig", export.path], passphrase: "")

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("Enter the passphrase again."), answer.errors)
    }

    func testASpotThatDoesNotTakeAnImportIsReportedAsSkipped() async throws {
        try "#!/bin/sh\n# title=Links\n# on=sheet.open\necho 'row=a'\n".writeScript(to: config.appendingPathComponent("spots/links.spot/links.sh"))

        let answer = try await answer(["import", "rayconfig", export.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(rows(answer).first, "links skipped Links did not take them. Your copy in the spots folder may be older than the one in Openspot: update it, then import again.")
    }

    func testAKindLeftOutIsNotImported() async throws {
        let answer = try await answer(["import", "rayconfig", export.path, "--skip", "snippets"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(rows(answer).prefix(2), ["links added Added 1 link to Links", "snippets skipped Left out"])
        XCTAssertEqual(data("snippets"), "")
    }
}
