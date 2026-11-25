import XCTest
@testable import OpenspotCore

final class AccountMarkerTests: BuiltInCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let marker = "abandon"

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    private func keepTheKey() throws {
        try store.keep(try AccountPhrase(phrase).key(), isBackedUp: false)
    }

    private func caller(_ id: String, uses: Set<SpotUse>, isBuiltIn: Bool) -> Spot {
        let spot = Spot(id: id, name: id, url: root.appendingPathComponent("\(id).sh"), dataName: id, uses: uses)
        return isBuiltIn ? spot.builtIn() : spot
    }

    private func verbsSaid() async -> [String] {
        let api = CommandAPI(mac: Mac(), places: .test(TestEnvironment.values), app: app, runs: runs)
        let callers: [Spot?] = [
            nil,
            caller("mine", uses: [.account], isBuiltIn: false),
            caller("openspot/settings", uses: [.app], isBuiltIn: true),
            caller("openspot/store", uses: [.app, .account], isBuiltIn: true)
        ]
        let verbs = [
            ["account", "show"], ["account", "show", "--json"], ["account", "words"], ["account", "choices", "1", "2"], ["account", "choices", "3", "4"],
            ["account", "checked"], ["account", "phrase"], ["account", "sign-in"], ["account", "new"], ["account", "new", "tony"],
            ["account", "sign-out"], ["account", "sync", "off"], ["account", "key"], ["account", "show"], ["help", "account"]
        ]
        var said: [String] = []
        for caller in callers {
            for arguments in verbs {
                let request = CommandRequest(arguments: arguments, folder: root.path, caller: caller.map { runs.callers.issue(for: $0) })
                guard let call = api.call(of: request), let work = api.work(for: api.admit(call, request: request), request: request, input: { "" }) else { continue }
                let answer = await work()
                said.append("\(arguments) from \(caller?.id ?? "Terminal") gave \(answer.output)\(answer.errors)")
            }
        }
        return said
    }

    private func runsSaid() async throws -> [String] {
        if !FileManager.default.fileExists(atPath: core.appendingPathComponent(SpotsFolder.appName).path) {
            try FileManager.default.copyItem(at: repoSpots.appendingPathComponent(SpotsFolder.appName), to: core.appendingPathComponent(SpotsFolder.appName))
        }
        let ids = try SpotsFolder(url: spots, core: core).scan().scripts.filter(\.reachesAccountKey).map(\.id)
        let command = tools.appendingPathComponent("openspot")
        var said: [String] = []
        for id in ids {
            for call in [[], ["show"], ["reveal"], ["again"], ["about"]] {
                do {
                    said.append("spot run \(id) \(call) gave " + (try await ScriptProcess.output(url: command, arguments: ["spot", "run", id] + call, input: "", limit: 60, base: TestEnvironment.values)))
                } catch {
                    said.append("spot run \(id) \(call) gave \(error)")
                }
            }
        }
        return said
    }

    private func everything(in folder: URL) -> String {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    func testNoAccountVerbGivesAWordToAnyCaller() async throws {
        try keepTheKey()

        for said in await verbsSaid() {
            XCTAssertFalse(said.contains(marker), said)
        }
    }

    func testARunOfASpotOfTheAppGivesNoWordToItsCaller() async throws {
        try keepTheKey()

        for said in try await runsSaid() {
            XCTAssertFalse(said.contains(marker), said)
        }
    }

    func testTheWholeFlowLeavesNoWordWhereAScriptOrACallerReads() async throws {
        let settings = try spot("settings")
        let app = app
        let links = SecretLinks(account: Account(store: store, allows: { await app.allows($0) }), keep: { _, _, _ in nil }).input
        let words = try XCTUnwrap(links["words"] as? () async -> ([String], String?))
        let choices = try XCTUnwrap(links["choices"] as? ([Int]) -> [[String]])
        let confirm = try XCTUnwrap(links["confirm"] as? ([Int], [String]) async -> String?)
        let signIn = try XCTUnwrap(links["signIn"] as? (String) async -> String?)
        var lines: [String] = []
        var failures: [String] = []
        let act = { (words: [String]) async in
            do {
                lines.append(try await self.runs.answer(of: settings, "window", input: "input.value=\(words.joined(separator: "\t"))\n", limit: 60))
            } catch {
                failures.append((error as? SpotError)?.reason ?? "\(error)")
            }
        }
        let check = { (all: [String]) async in
            let offered = choices([3, 9])
            lines.append("\(offered.count)")
            if let failure = await confirm([3, 9], [all[2], all[2] == "zoo" ? "abandon" : "zoo"]) { failures.append(failure) }
            if let failure = await confirm([3, 9], [all[2], all[8]]) { failures.append(failure) }
        }

        await act(["new", "tony"])
        XCTAssertEqual(try store.record()?.handle, "tony")
        let shown = await words()
        XCTAssertEqual(shown.0, try store.key()?.words)
        await check(shown.0)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        await act(["sign-out"])
        XCTAssertNil(try store.key())
        if let failure = await signIn("abandon abandon") { failures.append(failure) }
        if let failure = await signIn(phrase) { failures.append(failure) }
        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        await check(phrase.split(separator: " ").map(String.init))
        await app.set(allows: false)
        if let failure = (await words()).1 { failures.append(failure) }
        await act(["sign-out"])
        await app.set(allows: true)

        let verbs = await verbsSaid()
        let ran = try await runsSaid()
        runs.quit()
        let reached = verbs + ran + lines + failures + mac.copied + [everything(in: root.appendingPathComponent("logs")), everything(in: root.appendingPathComponent("stats"))]
        XCTAssertFalse(failures.isEmpty)
        for said in reached {
            XCTAssertFalse(said.contains(marker), said)
        }
    }
}
