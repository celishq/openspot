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
    public let handler: String
    public let started: Date
    public private(set) var status: TextBlock?
    public private(set) var isStopped = false
    @ObservationIgnored let key: String
    @ObservationIgnored var halt: () -> Void = {}
    @ObservationIgnored private(set) var heard = 0

    public let isAct: Bool

    init(handler: String, isAct: Bool, key: String, started: Date) {
        self.handler = handler
        self.isAct = isAct
        self.key = key
        self.started = started
    }

    nonisolated deinit {}

    public var fill: Double? {
        status?.number("progress").map { min(max($0, 0), 1) }
    }

    public var title: String? {
        status?.value("title")
    }

    public var detail: String? {
        status?.value("detail")
    }

    func take(_ output: Frame) {
        heard += 1
        guard !output.isPicture else { return }
        status = output.root
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        halt()
    }
}
