import Foundation

/// The exchange rates of currencies and crypto at one time, from Coinbase: how many of each one US dollar buys.
public struct CalcRates: Equatable, Sendable, Codable {
    /// Where the rates come from. It needs no key, and its answer changes about each minute.
    public static let source = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=USD")!

    public let time: Date
    private let perDollar: [String: Double]

    /// Reads the answer of `source`, taken at a time. Returns nil for an answer that is cut or holds no rates.
    public init?(coinbase: Data, time: Date) {
        struct Answer: Decodable {
            struct Body: Decodable { let rates: [String: String] }
            let data: Body
        }
        guard let answer = try? JSONDecoder().decode(Answer.self, from: coinbase) else { return nil }
        var perDollar = answer.data.rates.compactMapValues { Double($0) }.filter { $0.value > 0 }
        guard !perDollar.isEmpty else { return nil }
        perDollar["USD"] = 1
        self.time = time
        self.perDollar = perDollar
    }

    /// Reads the rates that `file` wrote, or returns nil for a file that is cut.
    public init?(file: Data) {
        guard let rates = try? JSONDecoder().decode(Self.self, from: file), !rates.perDollar.isEmpty else { return nil }
        self = rates
    }

    public var file: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    /// How many of one currency one of another buys, by their codes in any case. Nil when it knows either code not.
    public func rate(from: String, to: String) -> Double? {
        guard let from = perDollar[from.uppercased()], let to = perDollar[to.uppercased()] else { return nil }
        return to / from
    }
}
