import XCTest
@testable import OpenspotCore

final class CalcAnswerTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let ukrainian = Locale(identifier: "uk_UA")

    private func answer(_ text: String, in locale: Locale? = nil) -> CalcAnswer? {
        CalcAnswer(text: text, locale: locale ?? english)
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
        XCTAssertEqual(answer("5 km in mi")?.text, "row=3.10686\ntitle=3.10686 mi\ndetail=5 km in mi\n")
        let cases: [(String, String, String)] = [
            ("20 c in f", "68", "68°F"), ("20°C to °F", "68", "68°F"), ("1 gb in mb", "1000", "1000 MB"), ("60 km/h in mph", "37.2823", "37.2823 mph"),
            ("5 in in cm", "12.7", "12.7 cm"), ("3 days in hours", "72", "72 hr"), ("5km to miles", "3.10686", "3.10686 mi"),
            ("(2+3) kg in lb", "11.0231", "11.0231 lb"), ("1 l in ml", "1000", "1000 mL"), ("180 deg in rad", "3.14159", "3.14159 rad"),
        ]
        for (text, value, title) in cases {
            XCTAssertEqual(answer(text)?.value, value, text)
            XCTAssertEqual(answer(text)?.title, title, text)
        }
    }

    func testUnitsOfTwoKindsOrUnknownWordsHaveNoAnswer() {
        for text in ["5 km in kg", "5 apples in pears", "5 km in", "in mi", "5 km"] { XCTAssertNil(answer(text), text) }
    }
}
