import Foundation

enum CalcCall: NounCall {
    case solve(String)

    static let noun = CommandNoun("calc", group: .mac, verbs: [
        CommandVerb(
            "solve", "<words>...",
            "Prints the answer of a sum, such as 2*(3+4) or 15% of 80, a conversion, such as 5 km in mi or 15 usd in eur, or a date, such as today + 3 weeks, days until 25 dec or 3pm tokyo in kyiv, as a row. It prints nothing for words that are none. A currency with no rates prints status=offline with no internet, or status=unavailable when the source does not answer. Rates 3 days old or more say their age, with tone=warn. The row's id is the plain value. Rates come from exchange-api, a public-domain file that changes once a day."
        ) { words in
            words.none ? nil : Self.solve(words.rest.joined(separator: " "))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .solve(let words) = self else { return nil }
        return CalcCalls(rates: context.rates).solve(words)
    }
}
