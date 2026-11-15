import Foundation

struct CalcCalls {
    let rates: CalcRateCache

    func solve(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [rates] in
            if let answer = Self.answer(to: words, rates: nil) { return answer }
            return Self.answer(to: words, rates: await rates.answer()) ?? ""
        }
    }

    private static func answer(to words: String, rates: Result<CalcRates, CalcRateFailure>?) -> String? {
        var needsRates = false
        do throws(CalcRateFailure) {
            let answer = try CalcAnswer(text: words) {
                needsRates = true
                return rates ?? .failure(.unavailable)
            }
            return needsRates && rates == nil ? nil : answer?.text ?? ""
        } catch {
            return rates == nil ? nil : error.text
        }
    }
}
