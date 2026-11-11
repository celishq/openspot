import Foundation

/// A typed conversion, `<amount> <from> in <to>`, such as `5 km in mi` or `$15 to €`, with `to`, `as` or `into` in place of
/// `in`, or an amount alone, such as `15 usd`, with no `to`. It splits the words only, and the caller finds what the names
/// name.
struct CalcConversion: Sendable {
    private static let joins = ["in", "to", "as", "into"]

    let amount: CalcExpression
    let from: String
    let to: String?

    /// Each way to split the text, from the last join word first, so that `5 in in cm` reads `5 in` in `cm`, and last the
    /// whole text as an amount alone.
    static func splits(of text: String, locale: Locale) -> [CalcConversion] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let joined: [CalcConversion] = words.indices.reversed().compactMap { index in
            guard index > 0, index < words.count - 1, joins.contains(words[index].lowercased()) else { return nil }
            return conversion(of: words[..<index].joined(separator: " "), to: words[(index + 1)...].joined(separator: " "), locale: locale)
        }
        return joined + [conversion(of: text, to: nil, locale: locale)].compactMap { $0 }
    }

    private static func conversion(of quantity: String, to: String?, locale: Locale) -> CalcConversion? {
        guard let (amountText, from) = Self.quantity(quantity), let amount = CalcExpression(text: amountText, locale: locale) else { return nil }
        return CalcConversion(amount: amount, from: from, to: to)
    }

    private init(amount: CalcExpression, from: String, to: String?) {
        self.amount = amount
        self.from = from
        self.to = to
    }

    /// Splits `5 km`, `(2+3)kg` or `$15` into the amount and the name: the name follows the last digit or bracket, or else
    /// comes before the amount, as a symbol with no letters or digits.
    private static func quantity(_ text: String) -> (amount: String, name: String)? {
        guard let last = text.lastIndex(where: { ($0.isASCII && $0.isNumber) || $0 == ")" }) else { return nil }
        let end = text.index(after: last)
        let name = text[end...].trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return (String(text[..<end]), name) }
        let start = text.firstIndex { ($0.isASCII && $0.isNumber) || "(.-+".contains($0) } ?? text.startIndex
        let prefix = text[..<start].trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty, !prefix.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return (String(text[start...]), prefix)
    }
}
