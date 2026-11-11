import Foundation

/// The exchange rates of currencies and crypto for one day, from exchange-api, a public-domain file that changes once a day:
/// how many of each one US dollar buys, the day that they are of, and when they were fetched.
public struct CalcRates: Equatable, Sendable, Codable {
    /// The file and its backup address, tried in order. Neither needs a key or has a limit.
    public static let sources = [
        URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")!,
        URL(string: "https://latest.currency-api.pages.dev/v1/currencies/usd.json")!,
    ]

    public let time: Date
    /// The day that the rates are of, as the file writes it, such as `2026-11-10`.
    public let day: String
    private let perDollar: [String: Double]

    /// Reads the file of `sources`, fetched at a time. Returns nil for a file that is cut, or holds no day or no rates.
    public init?(exchangeAPI: Data, time: Date) {
        struct File: Decodable {
            let date: String
            let usd: [String: Double]
        }
        guard let file = try? JSONDecoder().decode(File.self, from: exchangeAPI) else { return nil }
        var perDollar = Dictionary(file.usd.filter { $0.value > 0 }.map { ($0.key.uppercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        guard !perDollar.isEmpty else { return nil }
        perDollar["USD"] = 1
        self.time = time
        day = file.date
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

    /// How many currencies it knows.
    public var count: Int {
        perDollar.count
    }

    /// Whether these rates may take the place of kept ones: they are of the same day or a later one, and they know at least
    /// half as many currencies, so that a broken or old copy of the file never replaces good rates.
    public func replaces(_ kept: CalcRates) -> Bool {
        day >= kept.day && count * 2 >= kept.count
    }

    /// How many of one currency one of another buys, by their codes in any case. Nil when it knows either code not.
    public func rate(from: String, to: String) -> Double? {
        guard let from = perDollar[from.uppercased()], let to = perDollar[to.uppercased()] else { return nil }
        return to / from
    }

    /// The first file of the sources that loads and reads as rates, so that a dead or broken address falls to the next. With
    /// none, it throws `offline` when a load said that the Mac has no internet, and else `unavailable`.
    public static func download(from sources: [URL] = sources, using load: @Sendable (URL) async throws -> Data) async throws -> Data {
        var failure = CalcRateFailure.unavailable
        for source in sources {
            do {
                let data = try await load(source)
                if CalcRates(exchangeAPI: data, time: Date()) != nil { return data }
            } catch {
                if CalcRateFailure(error) == .offline { failure = .offline }
            }
        }
        throw failure
    }
}
