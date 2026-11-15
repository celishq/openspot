import Foundation

struct CalcCalls {
    func solve(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work {
            do throws(CalcRateFailure) {
                return try CalcAnswer(text: words, rates: CalcRateCache.ask)?.text ?? ""
            } catch {
                return error.text
            }
        }
    }
}
