import Foundation

/// The answer to a typed sum or conversion, as one row: its id is the plain value to copy, its title the answer written the
/// way of the Mac, and its detail how the text was read. Text that is not a sum has no answer.
public struct CalcAnswer: Equatable, Sendable {
    /// The value with a dot and no grouping, such as `3.75`.
    public let value: String
    public let title: String
    public let detail: String

    public init?(text: String, locale: Locale = .autoupdatingCurrent) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let answer = Self.conversion(of: text, locale: locale) {
            self = answer
        } else if let expression = CalcExpression(text: text, locale: locale), !expression.isPlain {
            self.init(value: Self.plain(expression.value, digits: 15), title: Self.written(expression.value, locale: locale), detail: expression.detail)
        } else {
            return nil
        }
    }

    private init(value: String, title: String, detail: String) {
        self.value = value
        self.title = title
        self.detail = detail
    }

    /// The row that `openspot calc solve` prints.
    public var text: String {
        TextBlock(fields: [.init(key: "row", value: value), .init(key: "title", value: title), .init(key: "detail", value: detail)]).text
    }

    /// The first split of the text whose two names are units of one kind.
    private static func conversion(of text: String, locale: Locale) -> CalcAnswer? {
        for split in CalcConversion.splits(of: text, locale: locale) {
            guard let from = CalcUnit.named(split.from), let to = CalcUnit.named(split.to), CalcUnit.areAlike(from, to) else { continue }
            let value = Measurement(value: split.amount.value, unit: from).converted(to: to).value
            guard value.isFinite else { continue }
            let formatter = MeasurementFormatter()
            formatter.locale = locale
            formatter.unitOptions = .providedUnit
            formatter.unitStyle = .medium
            formatter.numberFormatter = significant(6, locale: locale)
            let title = formatter.string(from: Measurement(value: value, unit: to))
            return CalcAnswer(value: plain(value, digits: 6), title: title, detail: "\(split.amount.detail) \(split.from) in \(split.to)")
        }
        return nil
    }

    private static func plain(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)g", value)
    }

    /// A value written the way of the Mac, and in scientific notation when it is too large or too small for its digits.
    private static func written(_ value: Double, locale: Locale) -> String {
        let formatter = significant(15, locale: locale)
        formatter.numberStyle = abs(value) >= 1e15 || (value != 0 && abs(value) < 1e-9) ? .scientific : .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 15
        return formatter.string(from: NSNumber(value: value)) ?? plain(value, digits: 15)
    }

    private static func significant(_ digits: Int, locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = digits
        return formatter
    }
}
