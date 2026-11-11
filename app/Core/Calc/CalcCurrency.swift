import Foundation

/// The names of currencies in a conversion: a code such as `usd` or `btc`, a symbol such as `$`, or a word such as `euros`.
enum CalcCurrency {
    private static let fiat = Set(Locale.Currency.isoCurrencies.map { $0.identifier.uppercased() })

    /// The code that a name gives, or nil when it can name no currency. A code is two to five letters or digits that name no
    /// unit, and only the rates can say whether it is a real one.
    static func code(_ name: String) -> String? {
        let name = name.lowercased()
        switch name {
        case "$", "us$", "dollar", "dollars", "bucks": return "USD"
        case "€", "euro", "euros": return "EUR"
        case "£", "pound", "pounds", "sterling": return "GBP"
        case "¥", "yen": return "JPY"
        case "₴", "грн", "hryvnia", "hryvnias": return "UAH"
        case "₹", "rupee", "rupees": return "INR"
        case "₩", "won": return "KRW"
        case "₺", "lira": return "TRY"
        case "₪", "shekel", "shekels": return "ILS"
        case "zł", "zloty": return "PLN"
        case "₿", "bitcoin", "bitcoins": return "BTC"
        case "ether", "ethereum": return "ETH"
        default:
            guard (2...5).contains(name.count), name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }), CalcUnit.named(name) == nil else { return nil }
            return name.uppercased()
        }
    }

    /// Whether a code is a currency of a country, which macOS knows with no rates.
    static func isFiat(_ code: String) -> Bool {
        fiat.contains(code)
    }

    /// Whether a code names a currency that leaves no doubt: one of a country, bitcoin or ether. A conversion asks for rates
    /// only with one, so that a word such as `apr` or `pi` stays a date or a sum.
    static func isKnown(_ code: String) -> Bool {
        isFiat(code) || code == "BTC" || code == "ETH"
    }
}
