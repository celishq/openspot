import Foundation

/// The call of `openspot calc solve`: the answer of a sum, a conversion or a date as one row.
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
