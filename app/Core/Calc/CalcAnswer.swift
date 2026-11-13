import Foundation

/// The answer to a typed sum or conversion, as one row: its id is the plain value to copy, its title the answer written the
/// way of the Mac, and its detail how the text was read. It tries a conversion, then a sum, then a date, and a text that
/// starts as `2026-12-25` only as a date. Text that is none has no answer, and a currency with no rates to convert it has the
/// answer `status=offline`.
public struct CalcAnswer: Equatable, Sendable {
    /// The value with a dot and no grouping, such as `3.75`.
    public let value: String
    public let title: String
    public let detail: String
    /// Why there is no value, such as `offline`.
    public let status: String?
    /// `warn` for an answer from old rates.
    public let tone: String?
    /// The part of the title that names what the value counts, such as `€`, `mi` or `days`.
    public let unit: String?
    /// The day of the exchange rates of a currency, with their age when they are old, such as `Nov 2, 9 days old`.
    public let rates: String?

    /// Reads the text. `rates` gives the exchange rates, and is asked only for a currency.
    public init?(
        text: String,
        locale: Locale = .autoupdatingCurrent,
        clock: Calendar = .autoupdatingCurrent,
        now: Date = Date(),
        rates: @escaping () -> Result<CalcRates, CalcRateFailure> = { .failure(.offline) }
    ) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var asked: Result<CalcRates, CalcRateFailure>?
        let kept = {
            let answer = asked ?? rates()
            asked = answer
            return answer
        }
        let isDate = text.prefixMatch(of: /\d{4}-\d{1,2}-\d{1,2}(\s|$)/) != nil
        if let answer = Self.conversion(of: text, locale: locale, clock: clock, now: now, rates: kept) {
            self = answer
        } else if !isDate, let expression = CalcExpression(text: text, locale: locale), !expression.isPlain {
            self.init(value: Self.plain(expression.value, digits: 15), title: Self.written(expression.value, locale: locale), detail: expression.detail)
        } else if let date = CalcDate.answer(to: text, locale: locale, clock: clock, now: now) {
            self = date
        } else {
            return nil
        }
    }

    init(value: String, title: String, detail: String, unit: String? = nil, rates: String? = nil, status: String? = nil, tone: String? = nil) {
        self.value = value
        self.title = title
        self.detail = detail
        self.unit = unit
        self.rates = rates
        self.status = status
        self.tone = tone
    }

    /// The row that `openspot calc solve` prints, or its status.
    public var text: String {
        if let status { return TextBlock(fields: [.init(key: "status", value: status)]).text }
        let fields: [TextBlock.Field] = [.init(key: "row", value: value), .init(key: "title", value: title), .init(key: "detail", value: detail)]
        let more = [("unit", unit), ("rates", rates), ("tone", tone)].compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }
        return TextBlock(fields: fields + more).text
    }

    /// The first split of the text whose names are two units of one kind, or two currencies that the rates know.
    private static func conversion(of text: String, locale: Locale, clock: Calendar, now: Date, rates asking: () -> Result<CalcRates, CalcRateFailure>) -> CalcAnswer? {
        for split in CalcConversion.splits(of: text, locale: locale) {
            if let to = split.to, let answer = units(split.amount, from: split.from, to: to, locale: locale) { return answer }
            guard let from = CalcCurrency.code(split.from), let to = split.to.map(CalcCurrency.code) ?? locale.currency?.identifier, from != to,
                  CalcCurrency.isKnown(from) || (split.to != nil && CalcCurrency.isKnown(to)) else { continue }
            let rates: CalcRates
            switch asking() {
            case .success(let kept): rates = kept
            case .failure(let failure):
                if CalcCurrency.isKnown(from), CalcCurrency.isKnown(to) { return CalcAnswer(value: "", title: "", detail: "", status: failure.rawValue) }
                continue
            }
            guard let rate = rates.rate(from: from, to: to) else { continue }
            let value = split.amount.value * rate
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = to
            formatter.currencySymbol = CalcCurrency.symbol(of: to, written: formatter.currencySymbol)
            if !CalcCurrency.isFiat(to) {
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 8
            }
            let plain = NumberFormatter()
            plain.locale = Locale(identifier: "en_US_POSIX")
            plain.usesGroupingSeparator = false
            plain.maximumFractionDigits = formatter.maximumFractionDigits
            let age = days(of: rates, clock: clock, now: now)
            let old = age.map { $0 >= oldDays ? ", \(daysWritten($0, clock: clock, locale: locale)) old" : "" } ?? ""
            return CalcAnswer(
                value: plain.string(from: NSNumber(value: value)) ?? Self.plain(value, digits: 15),
                title: formatter.string(from: NSNumber(value: value)) ?? "",
                detail: "\(split.amount.detail) \(from) in \(to)",
                unit: formatter.currencySymbol,
                rates: "\(day(of: rates, clock: clock, now: now, locale: locale))\(old)",
                tone: old.isEmpty ? nil : "warn"
            )
        }
        return nil
    }

    private static func units(_ amount: CalcExpression, from: String, to: String, locale: Locale) -> CalcAnswer? {
        guard let fromUnit = CalcUnit.named(from), let toUnit = CalcUnit.named(to), CalcUnit.areAlike(fromUnit, toUnit) else { return nil }
        let value = Measurement(value: amount.value, unit: fromUnit).converted(to: toUnit).value
        guard value.isFinite else { return nil }
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter = significant(6, locale: locale)
        let title = formatter.string(from: Measurement(value: value, unit: toUnit))
        return CalcAnswer(value: plain(value, digits: 6), title: title, detail: "\(amount.detail) \(from) in \(to)", unit: unit(of: title, number: formatter.numberFormatter.string(from: NSNumber(value: value)) ?? ""))
    }

    /// The words of a title with no number, such as `mi` of `3.10686 mi`, as its formatter wrote the number.
    static func unit(of title: String, number: String) -> String? {
        let words = title.replacingOccurrences(of: number, with: "").trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{00A0}\u{202F}")))
        return words.isEmpty || number.isEmpty ? nil : words
    }

    /// The age in days from which an answer says that its rates are old. The file changes once a day.
    private static let oldDays = 3

    private static func date(of rates: CalcRates, clock: Calendar) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = clock.timeZone
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: rates.day)
    }

    /// The days from the day of the rates to the day of now, counted on the clock that it is given.
    private static func days(of rates: CalcRates, clock: Calendar, now: Date) -> Int? {
        date(of: rates, clock: clock).flatMap { clock.dateComponents([.day], from: clock.startOfDay(for: $0), to: clock.startOfDay(for: now)).day }
    }

    /// A count of days in the words of the Mac, such as `9 days`.
    private static func daysWritten(_ count: Int, clock: Calendar, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day]
        var calendar = clock
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: DateComponents(day: count)) ?? "\(count) days"
    }

    /// The day that the rates are of, such as `Nov 10`, with its year when it is not the year of now.
    private static func day(of rates: CalcRates, clock: Calendar, now: Date, locale: Locale) -> String {
        guard let date = date(of: rates, clock: clock) else { return rates.day }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = clock
        formatter.timeZone = clock.timeZone
        formatter.setLocalizedDateFormatFromTemplate(clock.isDate(date, equalTo: now, toGranularity: .year) ? "MMMd" : "yMMMd")
        return formatter.string(from: date)
    }

    /// A value with a dot, no grouping and at most `digits` significant digits, such as `5280000` or `0.000001`, and in
    /// scientific notation only from 10¹⁵ up.
    private static func plain(_ value: Double, digits: Int) -> String {
        let fallback = String(format: "%.\(digits)g", value)
        guard abs(value) < 1e15 else { return fallback }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? fallback
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
