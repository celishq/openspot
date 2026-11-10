@testable import OpenspotCore

/// The frames that one run reports, in order. It passes each report on to the listener the run had before.
@MainActor
final class FrameLog {
    private(set) var frames: [String] = []

    init(_ run: SpotRun) {
        let listener = run.onReport
        run.onReport = { [weak self] report in
            if case .frame(let text) = report { self?.frames.append(text) }
            listener(report)
        }
    }

    var last: String? {
        frames.last
    }
}
