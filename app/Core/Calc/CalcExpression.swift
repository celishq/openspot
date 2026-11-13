import Foundation

/// A typed sum read into its value: numbers, `+ - * / ^`, `%` as a part or a remainder, brackets, the functions `sqrt sin
/// cos tan ln log abs round` with angles in degrees, and the constants `pi` and `e`. It also says how it read the sum.
struct CalcExpression: Sendable {
    let value: Double
    /// The sum as it was read, written the way of the Mac, such as `2 × (3 + 4)`.
    let detail: String
    /// Whether the text was only a number, with no operator, function or constant, so that its value adds nothing.
    let isPlain: Bool

    init?(text: String, locale: Locale) {
        guard let tokens = CalcToken.tokens(in: text, locale: locale), !tokens.isEmpty else { return nil }
        var reader = Reader(tokens: tokens, locale: locale)
        guard let term = reader.additive(), reader.isAtEnd, term.value.isFinite else { return nil }
        value = term.isPercent ? term.value / 100 : term.value
        detail = term.text
        isPlain = reader.operations == 0
        guard value.isFinite else { return nil }
    }

    /// A value as it was read: a percent is a part of what it meets, and its text is how the detail writes it.
    private struct Term {
        var value: Double
        var text: String
        var isPercent = false

        var plain: Double { isPercent ? value / 100 : value }
    }

    private static let functions: [String: @Sendable (Double) -> Double] = [
        "sqrt": { $0.squareRoot() },
        "sin": { sin($0 * .pi / 180) },
        "cos": { cos($0 * .pi / 180) },
        "tan": { tan($0 * .pi / 180) },
        "ln": { log($0) },
        "log": { log10($0) },
        "abs": { abs($0) },
        "round": { $0.rounded() },
    ]

    private static let constants: [String: (value: Double, text: String)] = ["pi": (.pi, "π"), "π": (.pi, "π"), "e": (M_E, "e")]

    /// Reads the tokens from the first, one rule of precedence at a time.
    private struct Reader {
        let tokens: [CalcToken]
        let locale: Locale
        var index = 0
        /// How many operators, functions and constants it read.
        var operations = 0

        init(tokens: [CalcToken], locale: Locale) {
            self.tokens = tokens
            self.locale = locale
        }

        var isAtEnd: Bool { index == tokens.count }

        private var next: CalcToken? { index < tokens.count ? tokens[index] : nil }

        private func token(after offset: Int) -> CalcToken? {
            index + offset < tokens.count ? tokens[index + offset] : nil
        }

        /// Whether a token starts a value, which makes a `%` before it a remainder.
        private static func startsValue(_ token: CalcToken?) -> Bool {
            if case .number? = token { return true }
            return followsImplicitly(token)
        }

        /// Whether a token can follow a value with no operator and multiply it, as in `2(3+4)` or `2pi`. A number cannot, so
        /// `1 000` is no sum.
        private static func followsImplicitly(_ token: CalcToken?) -> Bool {
            switch token {
            case .symbol("(")?: true
            case .word(let word)?: functions[word] != nil || constants[word] != nil
            default: false
            }
        }

        mutating func additive() -> Term? {
            guard var left = multiplicative() else { return nil }
            while case .symbol(let symbol)? = next, symbol == "+" || symbol == "-" {
                index += 1
                guard let right = multiplicative() else { return nil }
                operations += 1
                let sign: Double = symbol == "+" ? 1 : -1
                let value = right.isPercent && !left.isPercent ? left.value * (1 + sign * right.value / 100) : left.plain + sign * right.plain
                left = Term(value: value, text: "\(left.text) \(symbol == "+" ? "+" : "−") \(right.text)")
            }
            return left
        }

        mutating func multiplicative() -> Term? {
            guard var left = unary() else { return nil }
            while true {
                let symbol: String
                switch next {
                case .symbol("*")?, .word("x")?: symbol = "×"
                case .symbol("/")?: symbol = "÷"
                case .symbol("%")?: symbol = "mod"
                case .word("of")? where left.isPercent: symbol = "of"
                case let token where Self.followsImplicitly(token): symbol = ""
                default: return left
                }
                if !symbol.isEmpty { index += 1 }
                guard let right = unary() else { return nil }
                operations += 1
                let value: Double = switch symbol {
                case "÷": left.plain / right.plain
                case "mod": left.plain.truncatingRemainder(dividingBy: right.plain)
                case "of": left.value / 100 * right.plain
                default: left.plain * right.plain
                }
                let text = symbol == "mod" ? "\(left.text) mod \(right.text)" : "\(left.text) \(symbol.isEmpty ? "×" : symbol) \(right.text)"
                left = Term(value: value, text: text)
            }
        }

        mutating func unary() -> Term? {
            guard case .symbol(let symbol)? = next, symbol == "-" || symbol == "+" else { return power() }
            index += 1
            guard let term = unary() else { return nil }
            return symbol == "-" ? Term(value: -term.value, text: "−\(term.text)", isPercent: term.isPercent) : term
        }

        mutating func power() -> Term? {
            guard let base = postfix() else { return nil }
            guard case .symbol("^")? = next else { return base }
            index += 1
            guard let exponent = unary() else { return nil }
            operations += 1
            return Term(value: pow(base.plain, exponent.plain), text: "\(base.text)\(Self.raised(exponent.text))")
        }

        /// An exponent of digits as superscript, such as `²⁰`, and any other after a `^`.
        private static func raised(_ text: String) -> String {
            let marks: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "−": "⁻"]
            guard text.allSatisfy({ marks[$0] != nil }) else { return "^\(text)" }
            return String(text.compactMap { marks[$0] })
        }

        /// A value with the `%` that follows it. A `%` before another value is a remainder, which `multiplicative` reads.
        mutating func postfix() -> Term? {
            guard var term = primary() else { return nil }
            if case .symbol("%")? = next, !Self.startsValue(token(after: 1)) {
                index += 1
                term = Term(value: term.value, text: "\(term.text)%", isPercent: true)
            }
            return term
        }

        mutating func primary() -> Term? {
            switch next {
            case .number(let number)?:
                index += 1
                return Term(value: number, text: Self.written(number, locale))
            case .symbol("(")?:
                index += 1
                guard let inner = additive(), case .symbol(")")? = next else { return nil }
                index += 1
                return Term(value: inner.plain, text: "(\(inner.text))")
            case .word(let word)?:
                if let constant = constants[word] {
                    index += 1
                    operations += 1
                    return Term(value: constant.value, text: constant.text)
                }
                guard let function = functions[word] else { return nil }
                index += 1
                guard let argument = unary() else { return nil }
                operations += 1
                let text = argument.text.hasPrefix("(") ? argument.text : "(\(argument.text))"
                return Term(value: function(argument.plain), text: "\(word)\(text)")
            default:
                return nil
            }
        }

        /// A number written the way of the Mac, with no grouping, so that the detail reads like the typed text.
        private static func written(_ number: Double, _ locale: Locale) -> String {
            let formatter = CalcFormats.formatter(NumberFormatter.self, "typed|\(CalcFormats.key(locale))") {
                let formatter = NumberFormatter()
                formatter.locale = locale
                formatter.usesGroupingSeparator = false
                formatter.usesSignificantDigits = true
                formatter.maximumSignificantDigits = 15
                return formatter
            }
            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        }
    }
}
