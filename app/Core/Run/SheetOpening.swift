import Foundation

@MainActor
public final class SheetOpening {
    public let answerPause: TimeInterval
    public let motionLength: TimeInterval
    public var moving: String? {
        didSet {
            guard moving != oldValue else { return }
            releaseFrames()
            if moving != nil { endMotionLater() }
        }
    }
    private var frameWaits: [CheckedContinuation<Void, Never>] = []
    private var motionSerial = 0
    private var held: (id: String, start: () -> Void)?
    private var pause: Task<Void, Never>?

    public init(answerPause: TimeInterval = MotionTokens.answerPause, motionLength: TimeInterval = MotionTokens.growSettle) {
        self.answerPause = answerPause
        self.motionLength = motionLength
    }

    nonisolated deinit {}

    func holdMotion(of id: String, limited: Bool, start: @escaping () -> Void) {
        pause?.cancel()
        held = (id, start)
        pause = limited ? Task { [weak self, answerPause] in
            try? await Task.sleep(for: .seconds(answerPause))
            guard !Task.isCancelled else { return }
            self?.startMotion(of: id)
        } : nil
    }

    func startMotion(of id: String) {
        dropMotion(of: id)?()
    }

    @discardableResult
    func dropMotion(of id: String) -> (() -> Void)? {
        guard let held, held.id == id else { return nil }
        self.held = nil
        pause?.cancel()
        pause = nil
        return held.start
    }

    func waitForMotion(of id: String) async {
        while moving == id {
            await withCheckedContinuation { frameWaits.append($0) }
        }
    }

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
