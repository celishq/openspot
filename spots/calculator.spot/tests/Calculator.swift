import Foundation
import JavaScriptCore

/// The calculator of calculator.js, loaded into JavaScriptCore, with a clock in Berlin at Wed 11 Nov 2026 14:05.
final class Calculator {
    static let now = 1_794_402_300_000.0
    static let rates = #"{"date":"2026-11-10","usd":{"usd":1,"eur":0.8973,"uah":45.4772,"jpy":153.2,"gbp":0.76,"apr":29.15,"btc":0.0000135794951796}}"#

    struct Answer: Decodable, Equatable {
        var item: String?
        var title: String?
        var detail: String?
        var unit: String?
        var rates: String?
        var tone: String?
        var status: String?

        /// The lines of the answer as the old command printed them, such as item=14, title=14 and detail=2 × (3 + 4).
        var text: String {
            if let status { return "status=\(status)\n" }
            return [("item", item), ("title", title), ("detail", detail), ("unit", unit), ("rates", rates), ("tone", tone)]
                .compactMap { key, value in value.map { "\(key)=\($0)\n" } }.joined()
        }
    }

    private struct Result: Decodable {
        let answer: Answer?
        let asks: Int
    }

    static let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CALCULATOR_SPOT"] ?? FileManager.default.currentDirectoryPath)

    private let context: JSContext

    init() throws {
        context = JSContext()
        var failure: String?
        context.exceptionHandler = { _, value in failure = value?.toString() }
        let text = try String(contentsOf: Self.folder.appendingPathComponent("calculator.js"), encoding: .utf8)
            .replacingOccurrences(of: "export default", with: "globalThis.handlers =")
        context.evaluateScript(text)
        context.evaluateScript("""
        function check(text, locale, zone, currency, rates, failure) {
          let asks = 0
          const answer = solve(text, { locale, currency, timeZone: zone, now: new Date(\(Self.now)), rates: () => {
            asks += 1
            const kept = rates ? ratesOf(rates) : null
            return kept ? { rates: kept } : { failure }
          } })
          return JSON.stringify({ answer, asks })
        }
        """)
        if let failure { throw NSError(domain: "Calculator", code: 1, userInfo: [NSLocalizedDescriptionKey: failure]) }
    }

    /// The answer to a text, and how many times it asked for the rates.
    func solve(_ text: String, locale: String = "en-US", zone: String = "Europe/Berlin", currency: String = "USD", rates: String? = nil, failure: String = "offline") -> (answer: Answer?, asks: Int) {
        let json = context.objectForKeyedSubscript("check").call(withArguments: [text, locale, zone, currency, rates ?? NSNull(), failure]).toString() ?? ""
        let result = try? JSONDecoder().decode(Result.self, from: Data(json.utf8))
        return (result?.answer, result?.asks ?? 0)
    }

    /// A value the script computes, such as a call of one of its functions.
    func evaluate(_ script: String) -> JSValue? {
        context.evaluateScript(script)
    }
}
