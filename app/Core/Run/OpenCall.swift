import Foundation

@MainActor
final class OpenCall {
    var request: SpotRun.Call
    let made: ScriptCall
    let begin = Date()
    var frames: [String] = []
    var drawn: String?
    var hasAnswer = false
    var answered: TimeInterval?
    var showedPicture = false
    var lastHead: Frame?
    var pushed: Frame?
    var selected: String?
    var form = Frame.empty
    var refusal: SpotError?

    init(_ request: SpotRun.Call, started: Date) {
        self.request = request
        let isAsk = if case .ask = request.purpose { true } else { false }
        made = ScriptCall(handler: request.handler, isAct: !isAsk, key: request.key, started: started)
    }

    func outcome(_ end: ScriptCall.End) -> CallOutcome {
        let seconds = Date().timeIntervalSince(begin)
        var outcome = CallOutcome(seconds: seconds)
        if case .failed(let error) = end { outcome.failure = StatsLog.Failure(error) }
        if case .ask(.show) = request.purpose { outcome.reason = request.event?.name }
        if case .ask = request.purpose, case .ended = end { outcome.answered = answered ?? seconds }
        return outcome
    }

    nonisolated deinit {}
}
