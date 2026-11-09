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
    /// The last frame, sorted by what each block is, read once as it arrives. A frame of progress holds the values that a
    /// metric prints.
    public private(set) var output: PluginOutput?
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

    /// The part of its ring that is full, from 0 to 1, from the `value` of the gauge of its last frame (R12). With no value,
    /// a spinner shows.
    public var fill: Double? {
        output?.progress?.number("value").map { min(max($0, 0), 1) }
    }

    /// The `title` of the gauge of its last frame.
    public var title: String? {
        output?.progress?.value("title")
    }

    /// The `detail` of the gauge of its last frame.
    public var detail: String? {
        output?.progress?.value("detail")
    }

    /// Takes a frame, and returns it sorted by what each block is.
    func take(frame: String) -> PluginOutput {
        let output = PluginOutput(text: frame)
        self.output = output
        return output
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
