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
}
