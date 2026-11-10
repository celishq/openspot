import Foundation

/// A typed conversion, `<amount> <from> in <to>`, such as `5 km in mi` or `(2+3) kg to lb`, with `to`, `as` or `into` in
/// place of `in`. It splits the words only, and the caller finds what `from` and `to` name.
struct CalcConversion: Sendable {
    private static let joins = ["in", "to", "as", "into"]

    let amount: CalcExpression
    let from: String
    let to: String

    /// Each way to split the text, from the last join word first, so that `5 in in cm` reads `5 in` in `cm`.
    static func splits(of text: String, locale: Locale) -> [CalcConversion] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        return words.indices.reversed().compactMap { index in
            guard index > 0, index < words.count - 1, joins.contains(words[index].lowercased()) else { return nil }
            let left = words[..<index].joined(separator: " ")
            let to = words[(index + 1)...].joined(separator: " ")
            guard let (amountText, from) = Self.quantity(left), let amount = CalcExpression(text: amountText, locale: locale) else { return nil }
            return CalcConversion(amount: amount, from: from, to: to)
        }
    }

    private init(amount: CalcExpression, from: String, to: String) {
        self.amount = amount
        self.from = from
        self.to = to
    }

    /// Splits `5 km` or `(2+3)kg` into the amount and the name after it: the name starts after the last digit or bracket.
    private static func quantity(_ text: String) -> (amount: String, name: String)? {
        guard let last = text.lastIndex(where: { ($0.isASCII && $0.isNumber) || $0 == ")" }) else { return nil }
        let end = text.index(after: last)
        let name = text[end...].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return (String(text[..<end]), name)
    }
}
