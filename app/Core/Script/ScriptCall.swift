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
    public private(set) var lastFrame: String?
    public private(set) var isStopped = false
    @ObservationIgnored let key: String
    @ObservationIgnored var halt: () -> Void = {}

    init(action: SpotAction, key: String, started: Date) {
        self.action = action
        self.key = key
        self.started = started
    }

    nonisolated deinit {}

    /// The last frame, sorted by what each block is. A frame of progress holds the values that a metric prints.
    public var output: PluginOutput? {
        lastFrame.map(PluginOutput.init(text:))
    }

    /// Whether this call does work: any name but `read`.
    public var doesWork: Bool {
        action.arguments.first != SpotAction.read.arguments.first
    }

    /// The part of its ring that is full, from 0 to 1, from the `value` of its last frame. With no value, a spinner shows.
    public var fill: Double? {
        output?.summary?.number("value").map { min(max($0, 0), 1) }
    }

    /// The `title` of its last frame.
    public var title: String? {
        output?.summary?.value("title")
    }

    /// The `detail` of its last frame.
    public var detail: String? {
        output?.summary?.value("detail")
    }

    func take(frame: String) {
        lastFrame = frame
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
