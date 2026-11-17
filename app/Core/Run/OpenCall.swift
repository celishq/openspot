import Foundation

@MainActor
final class OpenCall {
    var request: SpotRun.Call
    let made: ScriptCall
    let begin = Date()
    var frames: [String] = []
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
        if case .failed(let error) = end { outcome.failure = SpotUsage.Failure(error) }
        if case .ask(.read) = request.purpose { outcome.reason = request.reason.map(Self.name(of:)) }
        if case .ask = request.purpose, case .ended = end { outcome.answered = answered ?? seconds }
        return outcome
    }

    private static func name(of reason: ReadReason) -> String {
        reason.rawValue.hasPrefix(SpotEvent.clockPrefix) ? "clock" : reason.rawValue
    }

    nonisolated deinit {}
}
