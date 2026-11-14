import Foundation

public struct CalcAnswer: Equatable, Sendable {
    public let value: String
    public let title: String
    public let detail: String
    public let unit: String?
    public let rates: String?
    public let ratesAreOld: Bool

    public init?(
        text: String,
        locale: Locale = .autoupdatingCurrent,
        clock: Calendar = .autoupdatingCurrent,
        now: Date = Date(),
        rates: @escaping () -> Result<CalcRates, CalcRateFailure> = { .failure(.offline) }
    ) throws(CalcRateFailure) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var asked: Result<CalcRates, CalcRateFailure>?
        let kept = {
            let answer = asked ?? rates()
            asked = answer
            return answer
        }
        let isDate = text.prefixMatch(of: /\d{4}-\d{1,2}-\d{1,2}(\s|$)/) != nil
        if let answer = try Self.conversion(of: text, locale: locale, clock: clock, now: now, rates: kept) {
            self = answer
        } else if !isDate, let expression = CalcExpression(text: text, locale: locale), !expression.isPlain {
            self.init(value: Self.plain(expression.value, digits: 15), title: Self.written(expression.value, locale: locale), detail: expression.detail)
        } else if let date = CalcDate.answer(to: text, locale: locale, clock: clock, now: now) {
            self = date
        } else {
            return nil
        }
    }

    init(value: String, title: String, detail: String, unit: String? = nil, rates: String? = nil, ratesAreOld: Bool = false) {
        self.value = value
        self.title = title
        self.detail = detail
        self.unit = unit
        self.rates = rates
        self.ratesAreOld = ratesAreOld
    }

    public var text: String {
        let fields: [TextBlock.Field] = [.init(key: "row", value: value), .init(key: "title", value: title), .init(key: "detail", value: detail)]
        let more = [("unit", unit), ("rates", rates), ("tone", ratesAreOld ? "warn" : nil)].compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }
        return TextBlock(fields: fields + more).text
    }

    private static func conversion(of text: String, locale: Locale, clock: Calendar, now: Date, rates asking: () -> Result<CalcRates, CalcRateFailure>) throws(CalcRateFailure) -> CalcAnswer? {
        for split in CalcConversion.splits(of: text, locale: locale) {
            if let to = split.to, let answer = units(split.amount, from: split.from, to: to, locale: locale) { return answer }
            guard let from = CalcCurrency.code(split.from), let to = split.to.map(CalcCurrency.code) ?? locale.currency?.identifier, from != to,
                  CalcCurrency.isUnambiguous(from) || (split.to != nil && CalcCurrency.isUnambiguous(to)) else { continue }
            let rates: CalcRates
            switch asking() {
            case .success(let kept): rates = kept
            case .failure(let failure):
                if CalcCurrency.isUnambiguous(from), CalcCurrency.isUnambiguous(to) { throw failure }
                continue
            }
            guard let rate = rates.rate(from: from, to: to) else { continue }
            let value = split.amount.value * rate
            let formatter = CalcFormats.formatter(NumberFormatter.self, "currency|\(to)|\(CalcFormats.key(locale))") {
                let formatter = NumberFormatter()
                formatter.locale = locale
                formatter.numberStyle = .currency
                formatter.currencyCode = to
                formatter.currencySymbol = CalcCurrency.symbol(of: to, written: formatter.currencySymbol)
                if !CalcCurrency.isFiat(to) {
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 8
                }
                return formatter
            }
            let plain = CalcFormats.formatter(NumberFormatter.self, "plain|\(formatter.maximumFractionDigits)") {
                let plain = NumberFormatter()
                plain.locale = Locale(identifier: "en_US_POSIX")
                plain.usesGroupingSeparator = false
                plain.maximumFractionDigits = formatter.maximumFractionDigits
                return plain
            }
            let age = days(of: rates, clock: clock, now: now)
            let old = age.map { $0 >= oldRatesDays ? ", \(daysWritten($0, clock: clock, locale: locale)) old" : "" } ?? ""
            return CalcAnswer(
                value: plain.string(from: NSNumber(value: value)) ?? Self.plain(value, digits: 15),
                title: formatter.string(from: NSNumber(value: value)) ?? "",
                detail: "\(split.amount.detail) \(from) in \(to)",
                unit: formatter.currencySymbol,
                rates: "\(day(of: rates, clock: clock, now: now, locale: locale))\(old)",
                ratesAreOld: !old.isEmpty
            )
        }
        return nil
    }

    private static func units(_ amount: CalcExpression, from: String, to: String, locale: Locale) -> CalcAnswer? {
        guard let fromUnit = CalcUnit.named(from), let toUnit = CalcUnit.named(to), CalcUnit.areAlike(fromUnit, toUnit) else { return nil }
        let value = Measurement(value: amount.value, unit: fromUnit).converted(to: toUnit).value
        guard value.isFinite else { return nil }
        let formatter = CalcFormats.formatter(MeasurementFormatter.self, "units|\(CalcFormats.key(locale))") {
            let formatter = MeasurementFormatter()
            formatter.locale = locale
            formatter.unitOptions = .providedUnit
            formatter.unitStyle = .medium
            formatter.numberFormatter = significant(6, locale: locale)
            return formatter
        }
        let title = formatter.string(from: Measurement(value: value, unit: toUnit))
        return CalcAnswer(value: plain(value, digits: 6), title: title, detail: "\(amount.detail) \(from) in \(to)", unit: unit(of: title, number: formatter.numberFormatter.string(from: NSNumber(value: value)) ?? ""))
    }

    static func unit(of title: String, number: String) -> String? {
        let words = title.replacingOccurrences(of: number, with: "").trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{00A0}\u{202F}")))
        return words.isEmpty || number.isEmpty ? nil : words
    }

    private static let oldRatesDays = 3

    private static func date(of rates: CalcRates, clock: Calendar) -> Date? {
        let parser = CalcFormats.formatter(DateFormatter.self, "day|\(clock.timeZone.identifier)") {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.timeZone = clock.timeZone
            parser.dateFormat = "yyyy-MM-dd"
            return parser
        }
        return parser.date(from: rates.day)
    }

    private static func days(of rates: CalcRates, clock: Calendar, now: Date) -> Int? {
        date(of: rates, clock: clock).flatMap { clock.dateComponents([.day], from: clock.startOfDay(for: $0), to: clock.startOfDay(for: now)).day }
    }

    private static func daysWritten(_ count: Int, clock: Calendar, locale: Locale) -> String {
        let formatter = CalcFormats.formatter(DateComponentsFormatter.self, "days|\(CalcFormats.key(locale, clock))") {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.day]
            var calendar = clock
            calendar.locale = locale
            formatter.calendar = calendar
            return formatter
        }
        return formatter.string(from: DateComponents(day: count)) ?? "\(count) days"
    }

    private static func day(of rates: CalcRates, clock: Calendar, now: Date, locale: Locale) -> String {
        guard let date = date(of: rates, clock: clock) else { return rates.day }
        let template = clock.isDate(date, equalTo: now, toGranularity: .year) ? "MMMd" : "yMMMd"
        let formatter = CalcFormats.formatter(DateFormatter.self, "rates|\(template)|\(CalcFormats.key(locale, clock))") {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = clock
            formatter.timeZone = clock.timeZone
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }
        return formatter.string(from: date)
    }

    private static func plain(_ value: Double, digits: Int) -> String {
        let fallback = String(format: "%.\(digits)g", value)
        guard abs(value) < 1e15 else { return fallback }
        let formatter = CalcFormats.formatter(NumberFormatter.self, "plain digits|\(digits)") {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = digits
            return formatter
        }
        return formatter.string(from: NSNumber(value: value)) ?? fallback
    }

    private static func written(_ value: Double, locale: Locale) -> String {
        let style: NumberFormatter.Style = abs(value) >= 1e15 || (value != 0 && abs(value) < 1e-9) ? .scientific : .decimal
        let formatter = CalcFormats.formatter(NumberFormatter.self, "number|\(style.rawValue)|\(CalcFormats.key(locale))") {
            let formatter = significant(15, locale: locale)
            formatter.numberStyle = style
            return formatter
        }
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
