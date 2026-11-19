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
            guard let on = sheet.spot.on else { continue }
            let isWanted = sheet.isWanted
            if on.waitsForEvents {
                if !isWanted {
                    sheet.clockShown = nil
                } else if sheet.clockShown == nil {
                    sheet.clockShown = time
                    sheet.show(need: .clock, event: .clock(nil))
                }
                continue
            }
            guard isWanted, let seconds = on.seconds else { continue }
            if let last = sheet.clockShown, time.timeIntervalSince(last) < seconds {
                due = min(due ?? .distantFuture, last.addingTimeInterval(seconds))
            } else {
                sheet.clockShown = time
                sheet.show(need: .clock, event: .clock(seconds))
                due = min(due ?? .distantFuture, time.addingTimeInterval(seconds))
            }
        }
        return due
    }

    private func schedule(_ due: Date?) {
        guard due != nextShow || ticks == nil && due != nil else { return }
        ticks?.cancel()
        ticks = nil
        nextShow = due
        guard let due, !hasQuit else { return }
        let wait = Duration.seconds(max(0, due.timeIntervalSince(now())))
        ticks = Task { [weak self, sleep = clock.sleep] in
            try? await sleep(wait, wait / 10)
            guard !Task.isCancelled, let self else { return }
            ticks = nil
            nextShow = nil
            updateClock()
        }
    }
}
