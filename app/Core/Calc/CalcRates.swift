import Foundation

public struct CalcRates: Equatable, Sendable, Codable {
    public static let sources = [
        URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")!,
        URL(string: "https://latest.currency-api.pages.dev/v1/currencies/usd.json")!,
    ]

    public let time: Date
    public let day: String
    private let perDollar: [String: Double]

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

    public init?(file: Data) {
        guard let rates = try? JSONDecoder().decode(Self.self, from: file), !rates.perDollar.isEmpty else { return nil }
        self = rates
    }

    public var file: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public var count: Int {
        perDollar.count
    }

    public func replaces(_ kept: CalcRates) -> Bool {
        day >= kept.day && count * 2 >= kept.count
    }

    public func rate(from: String, to: String) -> Double? {
        guard let from = perDollar[from.uppercased()], let to = perDollar[to.uppercased()] else { return nil }
        return to / from
    }

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
