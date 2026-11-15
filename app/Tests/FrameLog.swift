@testable import OpenspotCore

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
