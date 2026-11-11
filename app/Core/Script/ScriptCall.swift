import Foundation
import Observation

/// One running call of a script, with the last frame it printed. A sheet lists its running calls, so that a place can show
/// them and a person can stop one.
@MainActor
@Observable
public final class ScriptCall: Identifiable {
    /// How a call ended. Only `ended` can report that there is nothing to show.
    public enum End: Sendable {
        case ended
        case failed(Error)
        case stopped
    }

    public let id = UUID()
    public let action: SpotAction
    public let started: Date
    /// The head of its last frame that held no block, whose `progress`, `title` and `detail` show while it runs (G4).
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

    /// Whether this call does work: any name but `read`.
    public var doesWork: Bool {
        action.arguments.first != SpotAction.read.arguments.first
    }

    /// The part of its ring that is full, from 0 to 1, from `progress` in its status (R12). With none, a spinner shows.
    public var fill: Double? {
        status?.number("progress").map { min(max($0, 0), 1) }
    }

    public var title: String? {
        status?.value("title")
    }

    public var detail: String? {
        status?.value("detail")
    }

    /// Takes a frame. Only a frame of only a head changes its status.
    func take(_ output: PluginOutput) {
        guard !output.isPicture else { return }
        status = output.summary
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
