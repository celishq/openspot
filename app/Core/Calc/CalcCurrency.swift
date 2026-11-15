import Foundation

enum CalcCurrency {
    private static let fiat = Set(Locale.Currency.isoCurrencies.map { $0.identifier.uppercased() })

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

    static func isFiat(_ code: String) -> Bool {
        fiat.contains(code)
    }

    static func symbol(of code: String, written: String) -> String {
        written == code ? homeSymbols[code] ?? written : written
    }

    private static let homeSymbols: [String: String] = Locale.availableIdentifiers.reduce(into: ["BTC": "₿"]) { symbols, identifier in
        let locale = Locale(identifier: identifier)
        guard let code = locale.currency?.identifier, let symbol = locale.currencySymbol, symbol != code else { return }
        if symbols[code].map({ symbol.count < $0.count }) ?? true { symbols[code] = symbol }
    }

    static func isUnambiguous(_ code: String) -> Bool {
        isFiat(code) || code == "BTC" || code == "ETH"
    }
}
