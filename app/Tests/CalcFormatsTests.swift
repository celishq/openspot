import XCTest
@testable import OpenspotCore

/// Proves that the kept formatters of Calc stay few and go when the person changes the language or the region.
final class CalcFormatsTests: XCTestCase {
    func testTheKeptFormattersStayUnderTheirLimit() {
        for index in 0..<(CalcFormats.limit * 3) {
            _ = CalcFormats.formatter(NumberFormatter.self, "test-limit-\(index)") { NumberFormatter() }
        }

        XCTAssertLessThanOrEqual(CalcFormats.count, CalcFormats.limit)
    }

    func testAChangeOfTheLocaleDropsTheKeptFormatters() {
        let first = CalcFormats.formatter(NumberFormatter.self, "test-locale") { NumberFormatter() }

        NotificationCenter.default.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)

        XCTAssertFalse(CalcFormats.formatter(NumberFormatter.self, "test-locale") { NumberFormatter() } === first)
    }
}
