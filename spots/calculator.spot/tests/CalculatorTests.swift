import XCTest

final class CalculatorTests: XCTestCase {
    private var calculator: Calculator!

    override func setUpWithError() throws {
        calculator = try Calculator()
    }

    private func answer(_ text: String, locale: String = "en-US", currency: String = "USD", rates: String? = nil, failure: String = "offline") -> Calculator.Answer? {
        calculator.solve(text, locale: locale, currency: currency, rates: rates, failure: failure).answer
    }

    private func spaced(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func testASumPrintsItsPlainValueItsAnswerAndHowItWasRead() {
        XCTAssertEqual(answer("2*(3+4)")?.text, "item=14\ntitle=14\ndetail=2 × (3 + 4)\n")
    }

    func testOperatorsKeepTheirOrder() {
        let cases: [(String, String)] = [
            ("15/4", "3.75"), ("2^10", "1024"), ("2^3^2", "512"), ("-2^2", "-4"), ("10-4-3", "3"), ("2+3*4", "14"),
            ("3x4", "12"), ("3 × 4 ÷ 2", "6"), ("7%3", "1"), ("7 % 3", "1"), ("2(3+4)", "14"), ("1/3", "0.333333333333333"),
            ("0.1+0.2", "0.3"), ("1,000*2", "2000"), ("1e3+1", "1001"), ("8 − 3", "5"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.item, value, text) }
    }

    func testAPercentIsAPartOfWhatItFollows() {
        let cases: [(String, String)] = [("15% of 80", "12"), ("80 + 15%", "92"), ("200 - 10%", "180"), ("80 * 15%", "12"), ("50% + 10", "10.5")]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.item, value, text) }
    }

    func testFunctionsTakeDegreesAndConstantsCount() {
        let cases: [(String, String)] = [
            ("sqrt(16)", "4"), ("sqrt 16 + 1", "5"), ("sin(30)", "0.5"), ("cos(60)", "0.5"), ("ln(e)", "1"), ("log(1000)", "3"),
            ("abs(-3)", "3"), ("round(2.5)", "3"), ("2pi", "6.28318530717959"), ("pi", "3.14159265358979"), ("π", "3.14159265358979"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text)?.item, value, text) }
    }

    func testTheAnswerIsWrittenTheWayOfTheMac() {
        XCTAssertEqual(answer("2^20")?.title, "1,048,576")
        XCTAssertEqual(answer("2^20")?.detail, "2²⁰")
        XCTAssertEqual(answer("2^(1+1)")?.detail, "2^(1 + 1)")
        XCTAssertNil(answer("2^20")?.unit)
        XCTAssertEqual(answer("2^64")?.title, "1.84467440737096E19")
        XCTAssertEqual(answer("1/2^40")?.title, "9.09494701772928E-13")
        XCTAssertEqual(answer("3,5*2", locale: "uk-UA")?.item, "7")
        XCTAssertEqual(answer("3.5*2", locale: "uk-UA")?.item, "7")
        XCTAssertEqual(answer("15/4", locale: "uk-UA")?.title, "3,75")
        XCTAssertEqual(answer("15/4", locale: "uk-UA")?.item, "3.75")
        XCTAssertNil(answer("1,5*2"))
    }

    func testTextThatIsNotASumHasNoAnswer() {
        for text in ["", "safari", "42", "-5", "2*(", "2*", "1/0", "sqrt(-1)", "(2+3", "2+3)", "15%", "hello world", "3 apples", "7 of 8", "x"] {
            XCTAssertNil(answer(text), text)
        }
    }

    func testAUnitConvertsToAnotherOfItsKind() {
        XCTAssertEqual(answer("5 km in mi")?.text, "item=3.10686\ntitle=3.10686 mi\ndetail=5 km in mi\nunit=mi\n")
        let cases: [(String, String, String)] = [
            ("20 c in f", "68", "68°F"), ("20°C to °F", "68", "68°F"), ("1 gb in mb", "1000", "1000 MB"), ("60 km/h in mph", "37.2823", "37.2823 mph"),
            ("5 in in cm", "12.7", "12.7 cm"), ("3 days in hours", "72", "72 hr"), ("5km to miles", "3.10686", "3.10686 mi"),
            ("(2+3) kg in lb", "11.0231", "11.0231 lb"), ("1 l in ml", "1000", "1000 mL"), ("180 deg in rad", "3.14159", "3.14159 rad"),
            ("1 km in mm", "1000000", "1000000 mm"), ("1 mm in km", "0.000001", "0.000001 km"),
        ]
        for (text, value, title) in cases {
            XCTAssertEqual(answer(text)?.item, value, text)
            XCTAssertEqual(answer(text)?.title, title, text)
        }
    }

    func testUnitsOfTwoKindsOrUnknownWordsHaveNoAnswer() {
        for text in ["5 km in kg", "5 apples in pears", "5 km in", "in mi", "5 km"] { XCTAssertNil(answer(text), text) }
    }

    func testACurrencyConvertsWithTheRatesAndNamesTheirDay() {
        let rates = Calculator.rates
        XCTAssertEqual(answer("15 usd in eur", rates: rates)?.text, "item=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 10\n")
        XCTAssertEqual(spaced(answer("15 usd in eur", locale: "uk-UA", rates: rates)?.title), "13,46 €")
        let cases: [(String, String)] = [
            ("$15 in eur", "13.46"), ("15$ to €", "13.46"), ("15 dollars in euros", "13.46"), ("100 eur in uah", "5068.23"),
            ("1 btc in usd", "73640.44"), ("100 usd in btc", "0.00135795"), ("1000 jpy in usd", "6.53"), ("(10+5) usd in eur", "13.46"),
        ]
        for (text, value) in cases { XCTAssertEqual(answer(text, rates: rates)?.item, value, text) }
        XCTAssertEqual(answer("1 btc in usd", rates: rates)?.title, "$73,640.44")
        XCTAssertEqual(spaced(answer("100 usd in btc", rates: rates)?.title), "₿0.00135795")
        XCTAssertEqual(answer("1000 jpy in usd", locale: "uk-UA", rates: rates)?.unit, "$")
    }

    func testCurrenciesTakeASumOfAmounts() {
        XCTAssertEqual(answer("$15 + 5 in eur", rates: Calculator.rates)?.item, "17.95")
        XCTAssertEqual(answer("(15 + 5) usd in eur", rates: Calculator.rates)?.item, "17.95")
    }

    func testAnAmountInACurrencyAloneConvertsToTheCurrencyOfTheMac() {
        XCTAssertEqual(answer("15 eur", currency: "UAH", rates: Calculator.rates)?.item, "760.23")
        XCTAssertEqual(spaced(answer("$15", locale: "uk-UA", currency: "UAH", rates: Calculator.rates)?.title), "682,16 ₴")
        XCTAssertNil(answer("15 usd", rates: Calculator.rates))
    }

    func testACurrencyTakesTheSymbolThatTheCalculatorReadsAndElseTheSymbolOfTheLocale() {
        let rates = #"{"date":"2026-11-10","usd":{"usd":1,"thb":32.5,"sek":9.4,"pln":3.6}}"#
        XCTAssertEqual(answer("1 usd in thb", rates: rates)?.unit, "THB")
        XCTAssertEqual(answer("1 usd in pln", locale: "en-US", rates: rates)?.unit, "zł")
        XCTAssertEqual(answer("1 usd in pln", locale: "pl-PL", rates: rates)?.unit, "zł")
    }

    func testUnitsWinOverCurrenciesAndUnknownCodesHaveNoAnswer() {
        XCTAssertEqual(answer("5 pounds in kg", rates: Calculator.rates)?.title, "2.26796 kg")
        XCTAssertEqual(answer("5 pounds in usd", rates: Calculator.rates)?.item, "6.58")
        XCTAssertNil(answer("15 abc in eur", rates: Calculator.rates))
        XCTAssertNil(answer("3 apples", rates: Calculator.rates))
    }

    func testOldRatesWarnWithTheirAge() {
        let old = Calculator.rates.replacingOccurrences(of: "2026-11-10", with: "2026-11-02")
        XCTAssertEqual(answer("15 usd in eur", rates: old)?.text, "item=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 2, 9 days old\ntone=warn\n")
        XCTAssertEqual(answer("15 usd in eur", rates: Calculator.rates)?.text, "item=13.46\ntitle=€13.46\ndetail=15 USD in EUR\nunit=€\nrates=Nov 10\n")
    }

    func testWithNoRatesAKnownCurrencySaysWhyAndAnUnknownOneSaysNothing() {
        XCTAssertEqual(answer("15 usd in eur", failure: "unavailable")?.text, "status=unavailable\n")
        XCTAssertEqual(answer("15 usd in eur")?.text, "status=offline\n")
        XCTAssertEqual(answer("15 usd in eur", failure: "loading")?.text, "status=loading\n")
        XCTAssertEqual(answer("1 btc in usd")?.status, "offline")
        XCTAssertNil(answer("1 xyz in abc"))
    }

    func testOnlyAConversionWithAKnownCurrencyUsesTheRates() {
        XCTAssertEqual(answer("15 apr in usd", rates: Calculator.rates)?.item, "0.51")
        XCTAssertNil(answer("15 apr", rates: Calculator.rates)?.rates)
        XCTAssertNil(answer("0.5 eth in btc", rates: Calculator.rates), "the rates of the test know no ETH")
    }

    func testRatesAreAskedOnlyForACurrency() {
        for text in ["2*(3+4)", "5 km in mi", "safari", "2 pi", "25 dec", "1 month", "1pas", "12am in utc", "2pm in pst", "15 apr", "3 cats in dogs"] {
            XCTAssertEqual(calculator.solve(text).asks, 0, text)
        }
        XCTAssertEqual(calculator.solve("15 usd in eur").asks, 1)
    }

    func testALengthMovesADate() {
        XCTAssertEqual(spaced(answer("today + 3 weeks")?.text), "item=2026-12-02\ntitle=Wed, Dec 2, 2026\ndetail=Wed, Nov 11, 2026 + 3 weeks\n")
        check([
            ("today - 10 days", "2026-11-01", "Sun, Nov 1, 2026"),
            ("tomorrow + 1 month", "2026-12-12", "Sat, Dec 12, 2026"),
            ("today + 1 year - 1 day", "2027-11-10", "Wed, Nov 10, 2027"),
            ("today+2d", "2026-11-13", "Fri, Nov 13, 2026"),
            ("now + 90 min", "2026-11-11 15:35", "Wed, Nov 11, 2026 at 3:35 PM"),
            ("now - 2 hours", "2026-11-11 12:05", "Wed, Nov 11, 2026 at 12:05 PM"),
            ("25.12.2026 + 1 week", "2027-01-01", "Fri, Jan 1, 2027"),
        ])
    }

    func testACountRunsToOrFromADate() {
        XCTAssertEqual(answer("days until 25 dec 2026")?.text, "item=44\ntitle=44 days\ndetail=Wed, Nov 11, 2026 to Fri, Dec 25, 2026\nunit=days\n")
        check([
            ("weeks until 25 dec 2026", "6", "6 weeks"),
            ("days since 1 jan 2026", "314", "314 days"),
            ("25 dec 2026 - today", "44", "44 days"),
            ("hours until tomorrow", "9", "9 hours"),
            ("days since 1 jan", "314", "314 days"),
            ("days until 25 dec", "44", "44 days"),
            ("weeks until 1 jan", "7", "7 weeks"),
        ])
    }

    func testATimeShowsInAnotherZone() {
        XCTAssertEqual(spaced(answer("3pm tokyo in berlin")?.text), "item=2026-11-11 07:00\ntitle=Wed 7:00 AM\ndetail=Wed 3:00 PM · Tokyo\nunit=AM\n")
        check([
            ("now in tokyo", "2026-11-11 22:05", "Wed 10:05 PM"),
            ("time in new york", "2026-11-11 08:05", "Wed 8:05 AM"),
            ("15:00 in kyiv", "2026-11-11 16:00", "Wed 4:00 PM"),
            ("noon utc in kyiv", "2026-11-11 14:00", "Wed 2:00 PM"),
            ("9:30 am pst in london", "2026-11-11 17:30", "Wed 5:30 PM"),
            ("3pm tokyo in kyiv", "2026-11-11 08:00", "Wed 8:00 AM"),
        ])
    }

    func testADateAloneSaysItsDay() {
        check([
            ("25.12.2026", "2026-12-25", "Fri, Dec 25, 2026"),
            ("2026-12-25", "2026-12-25", "Fri, Dec 25, 2026"),
            ("2026-12-25 + 1 week", "2027-01-01", "Fri, Jan 1, 2027"),
            ("dec 25 2026 3pm", "2026-12-25 15:00", "Fri, Dec 25, 2026 at 3:00 PM"),
            ("yesterday", "2026-11-10", "Tue, Nov 10, 2026"),
            ("15 apr", "2027-04-15", "Thu, Apr 15, 2027"),
            ("next friday", "2026-11-20", "Fri, Nov 20, 2026"),
            ("in 3 weeks", "2026-12-02", "Wed, Dec 2, 2026"),
        ])
    }

    func testWordsThatAreNoDateHaveNoAnswer() {
        for text in ["friday", "may", "today is", "3pm", "now in narnia", "days until", "today + 3 apples", "tomorrow never dies", "in 5",
                     "march madness", "today show", "time machine", "mon", "sun in london"] {
            XCTAssertNil(answer(text), text)
        }
    }

    func testTheRatesFileGivesTheRateOfEachCurrencyAndItsDay() {
        XCTAssertEqual(calculator.evaluate("ratesOf(\(js(Calculator.rates))).day")?.toString(), "2026-11-10")
        XCTAssertEqual(calculator.evaluate("ratesOf(\(js(Calculator.rates))).perDollar.EUR")?.toDouble(), 0.8973)
        XCTAssertEqual(calculator.evaluate("ratesOf(\(js(Calculator.rates))).perDollar.USD")?.toDouble(), 1)
    }

    func testACutOrEmptyFileGivesNoRates() {
        for file in [#"{"date":"2026-11-10","usd":{"#, #"{"date":"2026-11-10","usd":{}}"#, "", #"{"usd":{"eur":1}}"#] {
            XCTAssertTrue(calculator.evaluate("ratesOf(\(js(file))) === null")?.toBool() == true, file)
        }
    }

    func testNewRatesTakeThePlaceOfTheKeptOnlyWhenAsNewAndNearlyAsFull() {
        let full = #"{"date":"2026-11-10","usd":{"eur":1,"gbp":1,"jpy":1,"uah":1}}"#
        let cut = #"{"date":"2026-11-11","usd":{"eur":1}}"#
        let older = #"{"date":"2026-11-09","usd":{"eur":1,"gbp":1,"jpy":1,"uah":1}}"#
        let newer = #"{"date":"2026-11-11","usd":{"eur":1,"gbp":1}}"#
        let replaces = { (fresh: String, kept: String) in self.calculator.evaluate("replaces(ratesOf(\(self.js(fresh))), ratesOf(\(self.js(kept))))")?.toBool() }
        XCTAssertEqual(replaces(newer, full), true)
        XCTAssertEqual(replaces(cut, full), false)
        XCTAssertEqual(replaces(older, full), false)
    }

    func testTheTriggerTakesEachSymbolThatTheCalculatorReads() throws {
        let toml = try String(contentsOf: Calculator.folder.appendingPathComponent("spot.toml"), encoding: .utf8)
        let line = try XCTUnwrap(toml.split(separator: "\n").first { $0.hasPrefix("search = ") })
        let pattern = String(line.dropFirst("search = \"".count).dropLast()).replacingOccurrences(of: "\\\\", with: "\\")
        let trigger = try NSRegularExpression(pattern: pattern)
        let symbols = calculator.evaluate("JSON.stringify(Object.values(currencies).map((names) => names[0]).filter((symbol) => symbol && symbol.length === 1))")?.toString() ?? "[]"
        for symbol in try JSONDecoder().decode([String].self, from: Data(symbols.utf8)) {
            let text = "\(symbol)15"
            XCTAssertNotNil(trigger.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), symbol)
        }
    }

    private func check(_ cases: [(String, String, String)], file: StaticString = #filePath, line: UInt = #line) {
        for (text, value, title) in cases {
            XCTAssertEqual(answer(text)?.item, value, text, file: file, line: line)
            XCTAssertEqual(spaced(answer(text)?.title), title, text, file: file, line: line)
        }
    }

    private func js(_ text: String) -> String {
        String(decoding: try! JSONEncoder().encode(text), as: UTF8.self)
    }
}
