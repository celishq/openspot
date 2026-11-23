import XCTest
@testable import OpenspotCore

@MainActor
final class SpotCacheTests: SpotRunsCase {
    private var places: AppPlaces!

    private var cache: SpotCache {
        places.cache
    }

    override func setUp() async throws {
        try await super.setUp()
        places = .test(["OPENSPOT_CONFIG": folder.appendingPathComponent("config").path])
        runs.api = CommandAPI(mac: Mac(), places: places, runs: runs)
    }

    private func inline(toml: String, _ body: String) throws -> SpotRun {
        let url = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try toml.write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        return try sheet()
    }

    private func filling(_ age: String = "1d") throws -> SpotRun {
        try inline(toml: "[on]\nsearch = '^[0-9]'\n\"cache.rates\" = '\(age)'", """
        export default {
          search({ text }, env) {
            const rates = env.cache.get("rates")
            return `item=${text}\\ntitle=${rates ? rates.value : "loading"}\\n`
          },
          "cache.rates"(_, env) {
            const fills = env.cache.get("fills")
            env.cache.set("fills", String(Number(fills ? fills.value : "0") + 1))
            env.cache.set("rates", "fresh")
          },
        }
        """)
    }

    func testAKeptValueAnswersInTheTurnOfTheKeyWithItsAge() async throws {
        try cache.keep("kept", as: "rates", of: "script", at: Date().addingTimeInterval(-90))
        let sheet = try inline(toml: "[on]\nsearch = '^[0-9]'", """
        export default {
          search({ text }, env) {
            const rates = env.cache.get("rates")
            return `item=${text}\\ntitle=${rates.value}\\ndetail=${rates.age}\\n`
          },
        }
        """)
        sheet.answer("1")
        try await wait("the loaded script") { sheet.answers.map(\.run) == ["1"] }

        sheet.answer("7")

        XCTAssertEqual(sheet.answers.first?.title, "kept")
        XCTAssertEqual(sheet.answers.first?.subtitle, "90")
    }

    func testAMissingValueRunsItsFillerOnceAndTheSetAsksTheSpotAgain() async throws {
        let sheet = try filling()

        sheet.answer("1")
        sheet.answer("12")

        try await wait("the answer after the fill") { sheet.answers.first?.title == "fresh" && sheet.answers.map(\.run) == ["12"] }
        try await wait("the end of each call") { sheet.calls.isEmpty }
        XCTAssertEqual(cache.read("fills", of: "script")?.value, "1")
    }

    func testAValueOlderThanItsAgeRunsTheFillerAndAYoungerOneDoesNot() async throws {
        try cache.keep("old", as: "rates", of: "script", at: Date().addingTimeInterval(-2 * 86_400))
        let sheet = try filling()

        sheet.answer("1")

        try await wait("the answer after the fill") { sheet.answers.first?.title == "fresh" }
        sheet.answer("2")
        try await wait("the next answer") { sheet.answers.map(\.run) == ["2"] }
        try await wait("the end of each call") { sheet.calls.isEmpty }
        XCTAssertEqual(cache.read("fills", of: "script")?.value, "1")
    }

    func testASetOfTheSameValueAsksTheSpotNothingAgain() async throws {
        let sheet = try inline(toml: "[on]\nsearch = '^[0-9]'", """
        let searches = 0
        export default {
          search({ text }, env) {
            searches += 1
            env.cache.set("seen", "same")
            return `item=${text}\\ntitle=${searches}\\n`
          },
        }
        """)

        sheet.answer("1")

        try await wait("the answer") { sheet.answers.map(\.run) == ["1"] }
        try await wait("the end of each call") { sheet.calls.isEmpty }
        XCTAssertLessThanOrEqual(Int(sheet.answers.first?.title ?? "") ?? 99, 2)
    }

    func testACacheKeeps16MegabytesAtMostForEachSpot() throws {
        try cache.keep(String(repeating: "a", count: SpotCache.byteLimit - 10), as: "big", of: "one")

        XCTAssertThrowsError(try cache.keep(String(repeating: "b", count: 11), as: "more", of: "one"))
        XCTAssertNoThrow(try cache.keep(String(repeating: "b", count: 10), as: "more", of: "one"))
        XCTAssertNoThrow(try cache.keep(String(repeating: "c", count: 11), as: "more", of: "other"))
    }

    func testANameWithASlashIsRefused() {
        XCTAssertThrowsError(try cache.keep("x", as: "../rates", of: "one"))
    }

    func testAMemoryWarningDropsTheKeptCopiesAndTheNextReadTakesTheDisk() throws {
        let cache = SpotCache(folder: folder.appendingPathComponent("cache"))
        try cache.keep("first", as: "rates", of: "one")
        try "second".write(to: folder.appendingPathComponent("cache/one/rates"), atomically: true, encoding: .utf8)
        XCTAssertEqual(cache.read("rates", of: "one")?.value, "first")

        cache.dropMemory()

        XCTAssertEqual(cache.read("rates", of: "one")?.value, "second")
    }

    func testTheOnTableTakesAnAgeForEachCache() throws {
        let manifest = { (on: String) in try Manifest(text: "[on]\n\(on)", folder: "/spots/script.spot").script("script.js") }

        XCTAssertEqual(try manifest("\"cache.rates\" = '1d'\n\"cache.news\" = '30m'\n").triggers.fills, ["rates": 86_400, "news": 1_800])
        XCTAssertThrowsError(try manifest("\"cache.rates\" = 'soon'\n"))
        XCTAssertThrowsError(try manifest("\"cache.rates\" = true\n"))
    }
}
