import XCTest
@testable import OpenspotCore

final class CalcAnswerTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let ukrainian = Locale(identifier: "uk_UA")

    private let berlin: Calendar = {
        var clock = Calendar(identifier: .gregorian)
        clock.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return clock
    }()
    private let now = Date(timeIntervalSince1970: 1_794_402_300)

    private func answer(_ text: String, in locale: Locale? = nil, rates: CalcRates? = nil, failure: CalcRateFailure = .offline) -> CalcAnswer? {
        try? CalcAnswer(text: text, locale: locale ?? english, clock: berlin, now: now, rates: { rates.map { .success($0) } ?? .failure(failure) })
    }

    private func failure(_ text: String, _ failure: CalcRateFailure = .offline) -> CalcRateFailure? {
        do throws(CalcRateFailure) {
            _ = try CalcAnswer(text: text, locale: english, clock: berlin, now: now, rates: { .failure(failure) })
            return nil
        } catch {
            return error
        }
    }

    private func spaced(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func rates() -> CalcRates? {
        CalcRates(exchangeAPI: CalcRatesTests.file, time: now)
    }

    func testASumPrintsOneRowWithItsPlainValueItsAnswerAndHowItWasRead() {
        XCTAssertEqual(answer("2*(3+4)")?.text, "row=14\ntitle=14\ndetail=2 × (3 + 4)\n")
    }

    func testOperatorsKeepTheirOrder() {
        let cases: [(String, String)] = [
            ("15/4", "3.75"), ("2^10", "1024"), ("2^3^2", "512"), ("-2^2", "-4"), ("10-4-3", "3"), ("2+3*4", "14"),
            ("3x4", "12"), ("3 × 4 ÷ 2", "6"), ("7%3", "1"), ("7 % 3", "1"), ("2(3+4)", "14"), ("1/3", "0.333333333333333"),
            ("0.1+0.2", "0.3"), ("1,000*2", "2000"), ("1e3+1", "1001"), ("8 − 3", "5"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.value, value, text) }
    }

    func testAPercentIsAPartOfWhatItFollows() {
        let cases: [(String, String)] = [("15% of 80", "12"), ("80 + 15%", "92"), ("200 - 10%", "180"), ("80 * 15%", "12"), ("50% + 10", "10.5")]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.value, value, text) }
    }

    func testFunctionsTakeDegreesAndConstantsCount() {
        let cases: [(String, String)] = [
            ("sqrt(16)", "4"), ("sqrt 16 + 1", "5"), ("sin(30)", "0.5"), ("cos(60)", "0.5"), ("ln(e)", "1"), ("log(1000)", "3"),
            ("abs(-3)", "3"), ("round(2.5)", "3"), ("2pi", "6.28318530717959"), ("pi", "3.14159265358979"), ("π", "3.14159265358979"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.value, value, text) }
    }

    func testTheAnswerIsWrittenTheWayOfTheMac() {
        XCTAssertEqual(answer("2^20")?.title, "1,048,576")
        XCTAssertEqual(answer("2^20")?.detail, "2²⁰")
        XCTAssertEqual(answer("2^(1+1)")?.detail, "2^(1 + 1)")
        XCTAssertNil(answer("2^20")?.unit)
        XCTAssertEqual(answer("2^64")?.title, "1.84467440737096E19")
        XCTAssertEqual(answer("1/2^40")?.title, "9.09494701772928E-13")
        XCTAssertEqual(answer("3,5*2", in: ukrainian)?.value, "7")
        XCTAssertEqual(answer("3.5*2", in: ukrainian)?.value, "7")
        XCTAssertEqual(answer("15/4", in: ukrainian)?.title, "3,75")
        XCTAssertEqual(answer("15/4", in: ukrainian)?.value, "3.75")
        XCTAssertNil(answer("1,5*2"))
    }

    func testTextThatIsNotASumHasNoAnswer() {
        for text in ["", "safari", "42", "-5", "2*(", "2*", "1/0", "sqrt(-1)", "(2+3", "2+3)", "15%", "hello world", "3 apples", "7 of 8", "x"] {
            XCTAssertNil(answer(text), text)
        }
    }

    func testAUnitConvertsToAnotherOfItsKind() {
        XCTAssertEqual(answer("5 km in mi")?.text, "row=3.10686\ntitle=3.10686 mi\ndetail=5 km in mi\nunit=mi\n")
        let cases: [(String, String, String)] = [
            ("20 c in f", "68", "68°F"), ("20°C to °F", "68", "68°F"), ("1 gb in mb", "1000", "1000 MB"), ("60 km/h in mph", "37.2823", "37.2823 mph"),
            ("5 in in cm", "12.7", "12.7 cm"), ("3 days in hours", "72", "72 hr"), ("5km to miles", "3.10686", "3.10686 mi"),
            ("(2+3) kg in lb", "11.0231", "11.0231 lb"), ("1 l in ml", "1000", "1000 mL"), ("180 deg in rad", "3.14159", "3.14159 rad"),
            ("1 km in mm", "1000000", "1000000 mm"), ("1 mm in km", "0.000001", "0.000001 km"),
        ]
        for (text, value, title) in cases {
            XCTAssertEqual(answer(text)?.value, value, text)
            XCTAssertEqual(answer(text)?.title, title, text)
        }
    }

    func testUnitsOfTwoKindsOrUnknownWordsHaveNoAnswer() {
        for text in ["5 km in kg", "5 apples in pears", "5 km in", "in mi", "5 km"] { XCTAssertNil(answer(text), text) }
    }

    func testACurrencyConvertsWithTheRatesAndNamesTheirDay() {
        XCTAssertEqual(answer("15 usd in eur", rates: rates())?.text, "row=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 10\n")
        XCTAssertEqual(spaced(answer("15 usd in eur", in: ukrainian, rates: rates())?.title), "13,46 €")
        let cases: [(String, String)] = [
            ("$15 in eur", "13.46"), ("15$ to €", "13.46"), ("15 dollars in euros", "13.46"), ("100 eur in uah", "5068.23"),
            ("1 btc in usd", "73640.44"), ("100 usd in btc", "0.00135795"), ("1000 jpy in usd", "6.53"), ("(10+5) usd in eur", "13.46"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text, rates: rates())?.value, value, text) }
        XCTAssertEqual(answer("1 btc in usd", rates: rates())?.title, "$73,640.44")
        XCTAssertEqual(spaced(answer("100 usd in btc", rates: rates())?.title), "₿0.00135795")
        XCTAssertEqual(answer("1000 jpy in usd", in: ukrainian, rates: rates())?.unit, "$")
    }

    func testAnAmountInACurrencyAloneConvertsToTheCurrencyOfTheMac() {
        XCTAssertEqual(answer("15 eur", in: ukrainian, rates: rates())?.value, "760.23")
        XCTAssertEqual(spaced(answer("$15", in: ukrainian, rates: rates())?.title), "682,16 ₴")
        XCTAssertNil(answer("15 usd", rates: rates()))
    }

    func testUnitsWinOverCurrenciesAndUnknownCodesHaveNoAnswer() {
        XCTAssertEqual(answer("5 pounds in kg", rates: rates())?.title, "2.26796 kg")
        XCTAssertEqual(answer("5 pounds in usd", rates: rates())?.value, "6.58")
        XCTAssertNil(answer("15 abc in eur", rates: rates()))
        XCTAssertNil(answer("3 apples", rates: rates()))
    }

    func testOldRatesWarnWithTheirAge() throws {
        let file = String(decoding: CalcRatesTests.file, as: UTF8.self).replacingOccurrences(of: "2026-11-10", with: "2026-11-02")
        let old = try XCTUnwrap(CalcRates(exchangeAPI: Data(file.utf8), time: now))
        let yesterday = try XCTUnwrap(CalcRates(exchangeAPI: CalcRatesTests.file, time: now))

        XCTAssertEqual(answer("15 usd in eur", rates: old)?.text, "row=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 2, 9 days old\ntone=warn\n")
        XCTAssertEqual(answer("15 usd in eur", rates: yesterday)?.text, "row=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 10\n")
    }

    func testWithNoRatesAKnownCurrencySaysWhyAndAnUnknownOneSaysNothing() {
        XCTAssertEqual(failure("15 usd in eur", .unavailable)?.text, "status=unavailable\n")
        XCTAssertEqual(failure("15 usd in eur")?.text, "status=offline\n")
        XCTAssertEqual(failure("1 btc in usd"), .offline)
        XCTAssertNil(failure("1 xyz in abc"))
        XCTAssertNil(answer("1 xyz in abc"))
    }

    func testOnlyAConversionWithAKnownCurrencyUsesTheRates() {
        XCTAssertEqual(answer("15 apr in usd", rates: rates())?.value, "0.51")
        XCTAssertNil(answer("15 apr", rates: rates())?.rates)
        XCTAssertEqual(answer("0.5 eth in btc", rates: rates()), nil, "the rates of the test know no ETH")
    }

    func test_A42_ratesAreAskedOnlyForACurrency() {
        var asks = 0
        let count: () -> Result<CalcRates, CalcRateFailure> = {
            asks += 1
            return .failure(.offline)
        }
        _ = try? CalcAnswer(text: "2*(3+4)", locale: english, clock: berlin, now: now, rates: count)
        _ = try? CalcAnswer(text: "5 km in mi", locale: english, clock: berlin, now: now, rates: count)
        for text in ["safari", "2 pi", "25 dec", "1 month", "1pas", "12am in utc", "2pm in pst", "15 apr", "3 cats in dogs"] {
            _ = try? CalcAnswer(text: text, locale: english, clock: berlin, now: now, rates: count)
        }
        XCTAssertEqual(asks, 0)
        _ = try? CalcAnswer(text: "15 usd in eur", locale: english, clock: berlin, now: now, rates: count)
        XCTAssertEqual(asks, 1)
    }
}
