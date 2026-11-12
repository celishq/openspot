import Foundation

/// The call of `openspot calc solve`: the answer of a sum, a conversion or a date as one row.
struct CalcCalls {
    func solve(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { CalcAnswer(text: words, rates: CalcRateCache.ask)?.text ?? "" }
    }
}
