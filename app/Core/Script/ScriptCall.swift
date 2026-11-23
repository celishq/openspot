import Foundation
import Observation

@MainActor
@Observable
public final class ScriptCall: Identifiable {
    public enum End: Sendable {
        case ended
        case failed(Error)
        case stopped
    }

    public let id = UUID()
    public let action: SpotAction
    public let started: Date
    public private(set) var status: TextBlock?
    public private(set) var isStopped = false
    public private(set) var isBackground = false
    public private(set) var progress: WorkFill
    @ObservationIgnored let key: String
    @ObservationIgnored var halt: () -> Void = {}
    @ObservationIgnored private(set) var heard = 0

    init(action: SpotAction, key: String, started: Date) {
        self.action = action
        self.key = key
        self.started = started
        progress = WorkFill(base: 0, since: started)
    }

    nonisolated deinit {}

    public var doesWork: Bool {
        action.arguments.first != SpotAction.read.arguments.first
    }

    public var fill: Double? {
        status?.number("progress").map { min(max($0, 0), 1) }
    }

    public var title: String? {
        status?.value("title")
    }

    public var detail: String? {
        status?.value("detail")
    }

    func take(_ output: SpotOutput, at now: Date) {
        heard += 1
        if output.isBackground, !isBackground { isBackground = true }
        guard !output.isPicture else { return }
        let reported = fill
        status = output.summary
        if let fill, fill != reported { progress = progress.taking(fill, at: now) }
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
