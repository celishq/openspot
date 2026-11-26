import Foundation

extension SpotRuns {
    func timeNow() -> Date {
        now()
    }

    static let timelineHold: TimeInterval = 60

    func timelineUsed() {
        timelineUse = now()
        guard let rest = timelineRest, (timelineWatch.due ?? .distantFuture) > rest else { return }
        waitTimeline(until: nil)
    }

    private var timelineRest: Date? {
        timelineUse.map { $0.addingTimeInterval(Self.timelineHold) }.flatMap { $0 > now() ? $0 : nil }
    }

    private func tendTimeline() {
        let time = now()
        let isIdle = timelineRest == nil
        let timeline = timeline
        Task.detached { [weak self] in
            let due = timeline.cut(at: time)
            if isIdle { timeline.unload() }
            await self?.waitTimeline(until: due)
        }
    }

    private func waitTimeline(until due: Date?) {
        guard !hasQuit else { return }
        timelineWatch.wait(until: [due, timelineRest].compactMap { $0 }.min(), from: now()) { [weak self] in self?.tendTimeline() }
    }

    func timelineChanged(_ spot: String, by changer: String?) {
        for reader in timeline.readers(of: spot) where reader != changer {
            guard let sheet = sheets[reader], sheet.isOpen else { continue }
            sheet.show(need: .change)
        }
    }
}
