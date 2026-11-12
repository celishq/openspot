import Foundation

/// The open of a sheet, one at a time. Its motion waits for the sheet's first answer, for a short pause at most. What its
/// script prints while the motion runs waits for the end of the motion: a length after it starts, though its spring
/// settles later.
@MainActor
public final class SheetOpening {
    /// How many times slower each motion of the sheet runs, from `OPENSPOT_MOTION_SLOW`, so that a film can show each frame.
    public nonisolated static let slow = Double(ProcessInfo.processInfo.environment["OPENSPOT_MOTION_SLOW"] ?? "") ?? 1
    /// How long the open spring of a sheet takes.
    public nonisolated static let springDuration = 0.15 * slow
    /// How long a sheet with no answer yet holds its motion for the first answer.
    public let answerPause: TimeInterval
    /// How long the motion moves, until its spring of `springDuration` lies within a point of its end.
    public let motionLength: TimeInterval
    /// The sheet whose open motion runs. The model sets it when the motion starts and when it ends.
    public var moving: String? {
        didSet {
            guard moving != oldValue else { return }
            releaseFrames()
            if moving != nil { endMotionLater() }
        }
    }
    private var frameWaits: [CheckedContinuation<Void, Never>] = []
    private var motionSerial = 0
    /// The sheet whose motion waits for its first answer, and the start of that motion.
    private var held: (id: String, start: () -> Void)?
    private var pause: Task<Void, Never>?

    public init(answerPause: TimeInterval = 0.15, motionLength: TimeInterval = 0.25 * SheetOpening.slow) {
        self.answerPause = answerPause
        self.motionLength = motionLength
    }

    nonisolated deinit {}

    /// Holds the motion of a sheet until its first answer: for the pause at most, or, when it is not `limited`, until the
    /// answer comes or the sheet drops its motion.
    func holdMotion(of id: String, limited: Bool, start: @escaping () -> Void) {
        pause?.cancel()
        held = (id, start)
        pause = limited ? Task { [weak self, answerPause] in
            try? await Task.sleep(for: .seconds(answerPause))
            guard !Task.isCancelled else { return }
            self?.startMotion(of: id)
        } : nil
    }

    /// Starts the motion that this sheet holds, if it holds one.
    func startMotion(of id: String) {
        dropMotion(of: id)?()
    }

    /// Drops the motion that this sheet holds, and returns its start, or nil when the sheet holds none.
    @discardableResult
    func dropMotion(of id: String) -> (() -> Void)? {
        guard let held, held.id == id else { return nil }
        self.held = nil
        pause?.cancel()
        pause = nil
        return held.start
    }

    /// Waits while the open motion of this sheet runs.
    func waitForMotion(of id: String) async {
        while moving == id {
            await withCheckedContinuation { frameWaits.append($0) }
        }
    }

    /// Lets each waiting frame go and drops the held motion, so that nothing starts after the runs quit.
    func end() {
        moving = nil
        held = nil
        pause?.cancel()
        pause = nil
    }

    private func endMotionLater() {
        motionSerial += 1
        let serial = motionSerial
        Task { [weak self, motionLength] in
            try? await Task.sleep(for: .seconds(motionLength))
            guard let self, motionSerial == serial else { return }
            moving = nil
        }
    }

    private func releaseFrames() {
        let waits = frameWaits
        frameWaits = []
        waits.forEach { $0.resume() }
    }
}
