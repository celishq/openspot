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
    var lastHead: SpotOutput?
    var pushed: SpotOutput?
    var selected: String?
    var form = SpotOutput.empty

    init(_ request: SpotRun.Call, started: Date) {
        self.request = request
        made = ScriptCall(action: request.action, key: request.key, started: started)
    }

    func outcome(_ end: ScriptCall.End) -> CallOutcome {
        let seconds = Date().timeIntervalSince(begin)
        var outcome = CallOutcome(seconds: seconds)
        if case .failed(let error) = end { outcome.failure = StatsLog.Failure(error) }
        if case .ask(.show) = request.purpose { outcome.reason = request.event.map(Self.name(of:)) }
        if case .ask = request.purpose, case .ended = end { outcome.answered = answered ?? seconds }
        return outcome
    }

    private static func name(of event: ShowEvent) -> String {
        event.rawValue.hasPrefix(SpotEvent.clockPrefix) ? "clock" : event.rawValue
    }

    nonisolated deinit {}
}
