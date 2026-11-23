import Foundation

enum CalcCurrency {
    private static let fiat = Set(Locale.Currency.isoCurrencies.map { $0.identifier.uppercased() })

    static func code(_ name: String) -> String? {
        let name = name.lowercased()
        if let code = written[name] { return code }
        guard (2...5).contains(name.count), name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }), CalcUnit.named(name) == nil else { return nil }
        return name.uppercased()
    }

    static func isFiat(_ code: String) -> Bool {
        fiat.contains(code)
    }

    static func symbol(of code: String, written: String) -> String {
        written == code ? homeSymbols[code] ?? written : written
    }

    private static let symbols: [(code: String, symbol: String, words: [String])] = [
        ("USD", "$", ["us$", "dollar", "dollars", "bucks"]),
        ("EUR", "€", ["euro", "euros"]),
        ("GBP", "£", ["pound", "pounds", "sterling"]),
        ("JPY", "¥", ["yen"]),
        ("UAH", "₴", ["грн", "hryvnia", "hryvnias"]),
        ("INR", "₹", ["rupee", "rupees"]),
        ("KRW", "₩", ["won"]),
        ("TRY", "₺", ["lira"]),
        ("ILS", "₪", ["shekel", "shekels"]),
        ("PLN", "zł", ["zloty"]),
        ("BTC", "₿", ["bitcoin", "bitcoins"]),
        ("ETH", "", ["ether", "ethereum"]),
    ]

    private static let written: [String: String] = symbols.reduce(into: [:]) { codes, entry in
        if !entry.symbol.isEmpty { codes[entry.symbol] = entry.code }
        for word in entry.words { codes[word] = entry.code }
    }

    private static let homeSymbols: [String: String] = symbols.reduce(into: [:]) { kept, entry in
        if !entry.symbol.isEmpty { kept[entry.code] = entry.symbol }
    }

    static func isUnambiguous(_ code: String) -> Bool {
        isFiat(code) || code == "BTC" || code == "ETH"
    }
}
