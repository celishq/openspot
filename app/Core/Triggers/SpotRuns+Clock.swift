import Foundation

extension SpotRuns {
    func updateClock() {
        watchClipboard()
        watchLoad()
        schedule(tick())
    }

    private func tick() -> Date? {
        let time = now()
        var due: Date?
        for sheet in sheets.values {
            let on = sheet.spot.triggers
            guard on.shows else { continue }
            let isWanted = sheet.isWanted
            if on.waitsForEvents {
                if !isWanted {
                    sheet.clockShown = nil
                } else if sheet.clockShown == nil {
                    sheet.clockShown = time
                    sheet.show(need: .clock, event: .want)
                }
                continue
            }
            guard isWanted, let seconds = on.every.map(TimeInterval.init) else { continue }
            if let last = sheet.clockShown, time.timeIntervalSince(last) < seconds {
                due = min(due ?? .distantFuture, last.addingTimeInterval(seconds))
            } else {
                sheet.clockShown = time
                sheet.show(need: .clock, event: .clock)
                due = min(due ?? .distantFuture, time.addingTimeInterval(seconds))
            }
        }
        return due
    }

    private func schedule(_ due: Date?) {
        guard due != clockWatch.due || !clockWatch.isWaiting && due != nil else { return }
        clockWatch.wait(until: hasQuit ? nil : due, from: now()) { [weak self] in self?.updateClock() }
    }
}
