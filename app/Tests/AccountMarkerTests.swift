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
        let api = CommandAPI(mac: Mac(), places: .test(TestEnvironment.values), app: app, runs: runs, rates: .offline)
        let callers: [Spot?] = [
            nil,
            caller("mine", uses: [.account], isBuiltIn: false),
            caller("openspot/settings", uses: [.app], isBuiltIn: true),
            caller("openspot/store", uses: [.app, .account], isBuiltIn: true)
        ]
        let verbs = [
            ["account"], ["account", "--frame"], ["account", "words"], ["account", "choices", "1", "2"], ["account", "choices", "3", "4"],
            ["account", "checked"], ["account", "phrase"], ["account", "sign-in"], ["account", "new"], ["account", "new", "tony"],
            ["account", "sync", "off"], ["account", "key"], ["account", "show"], ["help", "account"]
        ]
        var said: [String] = []
        for caller in callers {
            for isBound in [true, false] {
                for arguments in verbs {
                    let request = CommandRequest(arguments: arguments, folder: root.path, token: caller.map { runs.tokens.issue(for: $0) }, isBound: isBound)
                    guard let call = api.call(of: request), let work = api.work(for: api.admit(call, request: request), request: request, input: { "" }) else { continue }
                    let answer = await work()
                    said.append("\(arguments) from \(caller?.id ?? "Terminal") gave \(answer.output)\(answer.errors)")
                }
            }
        }
        return said
    }

    private func runsSaid() async throws -> [String] {
        if !FileManager.default.fileExists(atPath: core.appendingPathComponent(SpotsFolder.appName).path) {
            try FileManager.default.copyItem(at: repoSpots.appendingPathComponent(SpotsFolder.appName), to: core.appendingPathComponent(SpotsFolder.appName))
        }
        let ids = try SpotsFolder(url: spots, core: core).scan().scripts.filter(\.reachesAccountKey).map(\.id) + [AccountSheet.id]
        let command = tools.appendingPathComponent("openspot")
        var said: [String] = []
        for id in ids {
            for call in [[], ["read"], ["show"], ["again"], ["about"]] {
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
        let app = app, mac = mac
        let sheet = AccountSheet(store: store, links: AccountSheet.Links(
            allows: { await app.allows($0) },
            copy: { mac.copied.append($0); return true },
            publish: { _ = await app.publish($0) },
            userName: { "Tony Pinkevych" }
        ))
        var lines: [String] = []
        var failures: [String] = []
        let frame = { (arguments: [String], input: String?, page: String?) async -> String in
            var variables = arguments == ["read"] ? ["OPENSPOT_REASON": "sheet.open"] : [:]
            if let page { variables["OPENSPOT_PAGE"] = page }
            do {
                let text = try await self.runs.answer(of: sheet.spot, SpotAction(arguments: arguments), input: input, limit: 60, variables: variables)
                lines += text.split(separator: "\n").filter { line in ["toast=", "push=", "pop="].contains { line.hasPrefix($0) } }.map(String.init)
                return text
            } catch {
                failures.append((error as? SpotError)?.reason ?? "\(error)")
                return ""
            }
        }
        let picks = { (text: String) -> [(place: Int, word: String)] in
            text.split(separator: "\n").filter { $0.hasPrefix("button=pick-") }.map { line in
                let rest = line.dropFirst("button=pick-".count)
                return (Int(rest.prefix { $0 != "-" }) ?? 0, String(rest.drop { $0 != "-" }.dropFirst()))
            }
        }

        let check = { (words: [String], wrongFirst: Bool) async throws in
            _ = await frame(["about"], nil, nil)
            let shown = await frame(["show"], nil, nil)
            XCTAssertTrue(shown.contains("title=\(words[0])"), shown)
            let asked = await frame(["wrote"], nil, nil)
            let places = Array(Set(picks(asked).map(\.place))).sorted()
            XCTAssertEqual(places.count, 2, asked)
            if wrongFirst {
                let wrong = try XCTUnwrap(picks(asked).first { $0.place == places[0] && $0.word != words[places[0] - 1] })
                _ = await frame(["pick-\(wrong.place)-\(wrong.word)"], nil, nil)
                _ = await frame(["pick-\(places[1])-\(words[places[1] - 1])"], nil, nil)
                return
            }
            for place in places { _ = await frame(["pick-\(place)-\(words[place - 1])"], nil, nil) }
        }

        _ = await frame(["new"], nil, nil)
        _ = await frame(["create"], "handle=tony\n", nil)
        XCTAssertEqual(try store.record()?.handle, "tony")
        let made = try XCTUnwrap(try store.key()?.words)
        try await check(made, true)
        XCTAssertFalse(try store.record()?.isBackedUp == true)
        try await check(made, false)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        _ = await frame(["leave"], nil, nil)
        _ = await frame(["sign_out"], nil, nil)
        XCTAssertNil(try store.key())
        _ = await frame(["own"], nil, nil)
        _ = await frame(["phrase", "abandon abandon"], nil, nil)
        _ = await frame(["sign_in"], "phrase=\(phrase)\n", nil)
        let words = try XCTUnwrap(try store.key()?.words)
        XCTAssertEqual(words.joined(separator: " "), phrase)
        try keepTheKey()
        _ = await frame(["read"], nil, nil)
        try await check(words, true)
        try await check(words, false)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        await app.set(allows: false)
        _ = await frame(["show"], nil, nil)
        _ = await frame(["sign_out"], nil, nil)
        await app.set(allows: true)
        _ = await frame(["new"], nil, "publish:a")
        let published = try await runs.answer(of: try spot("store"), SpotAction(arguments: ["gallery", "publish:a"]), limit: 60)
        let opened = await app.opened
        XCTAssertTrue(opened.contains("publish a"), "\(opened)")

        let verbs = await verbsSaid()
        let ran = try await runsSaid()
        runs.quit()
        let reached = verbs + ran + lines + failures + mac.copied + [published, everything(in: root.appendingPathComponent("logs")), everything(in: root.appendingPathComponent("stats"))]
        XCTAssertFalse(failures.isEmpty)
        for said in reached {
            XCTAssertFalse(said.contains(marker), said)
        }
    }
}
