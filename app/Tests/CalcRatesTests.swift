import XCTest
@testable import OpenspotCore

final class CalcRatesTests: XCTestCase {
    static let coinbase = Data(#"{"data":{"currency":"USD","rates":{"USD":"1.0","EUR":"0.8973","UAH":"45.4772","JPY":"153.2","GBP":"0.76","BTC":"0.0000135794951796"}}}"#.utf8)
    private let time = Date(timeIntervalSince1970: 1_800_000_000)
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-rates-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    func testCoinbaseGivesTheRateOfEachCurrencyInEachOther() throws {
        let rates = try XCTUnwrap(CalcRates(coinbase: Self.coinbase, time: time))
        XCTAssertEqual(rates.rate(from: "USD", to: "EUR"), 0.8973)
        XCTAssertEqual(try XCTUnwrap(rates.rate(from: "eur", to: "uah")), 45.4772 / 0.8973, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(rates.rate(from: "BTC", to: "USD")), 1 / 0.0000135794951796, accuracy: 1e-6)
        XCTAssertNil(rates.rate(from: "USD", to: "XYZ"))
        XCTAssertEqual(rates.time, time)
    }

    func testAnAnswerThatIsCutOrEmptyGivesNoRates() {
        XCTAssertNil(CalcRates(coinbase: Data(#"{"data":{"currency":"USD","rates":{"EUR":"0.9"#.utf8), time: time))
        XCTAssertNil(CalcRates(coinbase: Data(#"{"data":{"currency":"USD","rates":{}}}"#.utf8), time: time))
        XCTAssertNil(CalcRates(file: Data("{".utf8)))
    }

    func testRatesKeptInAFileReadBackTheSame() throws {
        let rates = try XCTUnwrap(CalcRates(coinbase: Self.coinbase, time: time))
        XCTAssertEqual(CalcRates(file: rates.file), rates)
    }

    /// A source that counts its fetches, and answers each with the rates of the test or fails.
    private actor Source {
        var count = 0
        var fails = false

        func fetch() throws -> Data {
            count += 1
            if fails { throw URLError(.notConnectedToInternet) }
            return CalcRatesTests.coinbase
        }

        func setFails(_ value: Bool) { fails = value }
    }

    /// A clock that a test moves.
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
