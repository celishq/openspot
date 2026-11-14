import XCTest
@testable import OpenspotCore

final class CalcRatesTests: XCTestCase {
    static let file = Data(#"{"date":"2026-11-10","usd":{"usd":1,"eur":0.8973,"uah":45.4772,"jpy":153.2,"gbp":0.76,"apr":29.15,"btc":0.0000135794951796}}"#.utf8)
    private let time = Date(timeIntervalSince1970: 1_800_000_000)
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-rates-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    func testTheFileGivesTheRateOfEachCurrencyInEachOtherAndItsDay() throws {
        let rates = try XCTUnwrap(CalcRates(exchangeAPI: Self.file, time: time))
        XCTAssertEqual(rates.day, "2026-11-10")
        XCTAssertEqual(rates.rate(from: "USD", to: "EUR"), 0.8973)
        XCTAssertEqual(try XCTUnwrap(rates.rate(from: "eur", to: "uah")), 45.4772 / 0.8973, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(rates.rate(from: "BTC", to: "USD")), 1 / 0.0000135794951796, accuracy: 1e-6)
        XCTAssertNil(rates.rate(from: "USD", to: "XYZ"))
        XCTAssertEqual(rates.time, time)
    }

    func testAFileThatIsCutOrEmptyGivesNoRates() {
        XCTAssertNil(CalcRates(exchangeAPI: Data(#"{"date":"2026-11-10","usd":{"eur":0.9"#.utf8), time: time))
        XCTAssertNil(CalcRates(exchangeAPI: Data(#"{"date":"2026-11-10","usd":{}}"#.utf8), time: time))
        XCTAssertNil(CalcRates(exchangeAPI: Data(#"{"usd":{"eur":0.9}}"#.utf8), time: time))
        XCTAssertNil(CalcRates(file: Data("{".utf8)))
    }

    func testADownloadFallsToTheBackupAddressWhenTheFirstFailsOrIsBroken() async throws {
        let first = try XCTUnwrap(URL(string: "https://first.example/usd.json"))
        let backup = try XCTUnwrap(URL(string: "https://backup.example/usd.json"))
        let failing: @Sendable (URL) async throws -> Data = { url in
            guard url == backup else { throw URLError(.cannotFindHost) }
            return Self.file
        }
        let broken: @Sendable (URL) async throws -> Data = { url in url == backup ? Self.file : Data("<html>".utf8) }

        let fromFailing = try await CalcRates.download(from: [first, backup], using: failing)
        let fromBroken = try await CalcRates.download(from: [first, backup], using: broken)
        XCTAssertEqual(fromFailing, Self.file)
        XCTAssertEqual(fromBroken, Self.file)
        do {
            _ = try await CalcRates.download(from: [first], using: failing)
            XCTFail("a download with no source that answers gives no file")
        } catch {}
    }

    func testRatesKeptInAFileReadBackTheSame() throws {
        let rates = try XCTUnwrap(CalcRates(exchangeAPI: Self.file, time: time))
        XCTAssertEqual(CalcRates(file: rates.file), rates)
    }

    private actor Source {
        var count = 0
        var fails = false
        var error: Error = URLError(.notConnectedToInternet)
        var file = CalcRatesTests.file

        func fetch() throws -> Data {
            count += 1
            if fails { throw error }
            return file
        }

        func setFails(_ value: Bool, with error: Error = URLError(.notConnectedToInternet)) {
            fails = value
            self.error = error
        }

        func setFile(_ value: Data) { file = value }
    }

    private final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func cache(_ source: Source, _ clock: Clock) -> CalcRateCache {
        CalcRateCache(file: folder.appendingPathComponent("rates.json"), now: { clock.now }, fetch: { try await source.fetch() })
    }

    func testTheFirstAskWaitsForTheRatesAndKeepsThemInTheFile() async throws {
        let source = Source()
        let rates = await cache(source, Clock()).rates()
        XCTAssertEqual(rates?.rate(from: "USD", to: "EUR"), 0.8973)
        let kept = try Data(contentsOf: folder.appendingPathComponent("rates.json"))
        XCTAssertEqual(CalcRates(file: kept), rates)
        let count = await source.count
        XCTAssertEqual(count, 1)
    }

    func testFreshRatesAnswerWithNoFetch() async {
        let source = Source()
        let clock = Clock()
        let cache = cache(source, clock)
        _ = await cache.rates()
        clock.now += 60
        _ = await cache.rates()
        await cache.settled()
        let count = await source.count
        XCTAssertEqual(count, 1)
    }

    func testAFileFromAnEarlierHelperAnswersAtOnceAndOldRatesComeNewInTheBackground() async throws {
        let clock = Clock()
        _ = await cache(Source(), clock).rates()
        clock.now += CalcRateCache.freshness + 1
        let source = Source()
        let cache = cache(source, clock)
        let old = await cache.rates()
        XCTAssertEqual(old?.time, Date(timeIntervalSince1970: 1_800_000_000))
        await cache.settled()
        let new = await cache.rates()
        XCTAssertEqual(new?.time, clock.now)
        let count = await source.count
        XCTAssertEqual(count, 1)
    }

    func testWithNoInternetOldRatesStayAndNoRatesMeanNone() async throws {
        let clock = Clock()
        let source = Source()
        await source.setFails(true)
        let cache = cache(source, clock)
        let none = await cache.rates()
        XCTAssertNil(none)
        let again = await cache.rates()
        XCTAssertNil(again)
        var count = await source.count
        XCTAssertEqual(count, 1, "A failed fetch waits a minute before the next one")
        clock.now += 61
        await source.setFails(false)
        _ = await cache.rates()
        clock.now += CalcRateCache.freshness + 1
        await source.setFails(true)
        let kept = await cache.rates()
        await cache.settled()
        XCTAssertEqual(kept?.rate(from: "USD", to: "EUR"), 0.8973)
        count = await source.count
        XCTAssertEqual(count, 3)
    }

    func testRatesADayOldWaitForNewOnesAndKeepTheOldWhenNoneCome() async throws {
        let clock = Clock()
        _ = await cache(Source(), clock).rates()
        clock.now += CalcRateCache.staleness + 1
        let fresh = await cache(Source(), clock).rates()
        XCTAssertEqual(fresh?.time, clock.now)
        clock.now += CalcRateCache.staleness + 1
        let source = Source()
        await source.setFails(true)
        let kept = await cache(source, clock).rates()
        XCTAssertEqual(kept?.time, clock.now - CalcRateCache.staleness - 1)
    }

    func testNoRatesSayWhetherTheInternetOrTheSourceIsDown() async {
        let offline = Source()
        await offline.setFails(true)
        let dead = Source()
        await dead.setFails(true, with: URLError(.badServerResponse))

        let none = await cache(offline, Clock()).answer()
        let down = await cache(dead, Clock()).answer()
        XCTAssertEqual(none, .failure(.offline))
        XCTAssertEqual(down, .failure(.unavailable))
    }

    func test_A41_aFileWithFarFewerCurrenciesOrAnOlderDayLeavesTheKeptRates() async throws {
        let clock = Clock()
        _ = await cache(Source(), clock).rates()
        let source = Source()
        let cache = cache(source, clock)
        for file in [#"{"date":"2026-11-11","usd":{"eur":0.9}}"#, #"{"date":"2026-11-01","usd":{"usd":1,"eur":0.9,"uah":45,"jpy":150,"gbp":0.7,"apr":29,"btc":0.00001}}"#] {
            await source.setFile(Data(file.utf8))
            clock.now += CalcRateCache.staleness + CalcRateCache.retry + 1
            let kept = await cache.rates()
            await cache.settled()
            XCTAssertEqual(kept?.day, "2026-11-10", file)
            let again = await cache.rates()
            XCTAssertEqual(again?.day, "2026-11-10", file)
        }
    }

    func testADownloadThatFindsNoFileSaysWhetherTheInternetIsDown() async throws {
        let first = try XCTUnwrap(URL(string: "https://first.example/usd.json"))
        let backup = try XCTUnwrap(URL(string: "https://backup.example/usd.json"))
        do {
            _ = try await CalcRates.download(from: [first, backup]) { _ in throw URLError(.notConnectedToInternet) }
            XCTFail("no file")
        } catch {
            XCTAssertEqual(error as? CalcRateFailure, .offline)
        }
        do {
            _ = try await CalcRates.download(from: [first, backup]) { _ in Data("<html>".utf8) }
            XCTFail("no file")
        } catch {
            XCTAssertEqual(error as? CalcRateFailure, .unavailable)
        }
    }

    func testACutFileCountsAsNone() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{\"time\":".utf8).write(to: folder.appendingPathComponent("rates.json"))
        let source = Source()
        let rates = await cache(source, Clock()).rates()
        XCTAssertNotNil(rates)
        let count = await source.count
        XCTAssertEqual(count, 1)
    }
}
