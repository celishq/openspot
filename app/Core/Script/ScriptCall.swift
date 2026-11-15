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
    @ObservationIgnored let key: String
    @ObservationIgnored var halt: () -> Void = {}

    init(action: SpotAction, key: String, started: Date) {
        self.action = action
        self.key = key
        self.started = started
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

    func take(_ output: SpotOutput) {
        guard !output.isPicture else { return }
        status = output.summary
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
