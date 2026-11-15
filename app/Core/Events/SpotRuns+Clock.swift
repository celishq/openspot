import Foundation

extension SpotRuns {
    func updateClock() {
        watchClipboard()
        schedule(tick())
    }

    private func tick() -> Date? {
        clockPasses += 1
        let time = now()
        var due: Date?
        for sheet in sheets.values {
            guard let read = sheet.spot.read else { continue }
            let isWanted = sheet.isWanted
            if read.waitsForEvents {
                if !isWanted {
                    sheet.clockRead = nil
                } else if sheet.clockRead == nil {
                    sheet.clockRead = time
                    sheet.read(need: .clock, reason: .clock(nil))
                }
                continue
            }
            guard isWanted, let seconds = read.seconds else { continue }
            if let last = sheet.clockRead, time.timeIntervalSince(last) < seconds {
                due = min(due ?? .distantFuture, last.addingTimeInterval(seconds))
            } else {
                sheet.clockRead = time
                sheet.read(need: .clock, reason: .clock(seconds))
                due = min(due ?? .distantFuture, time.addingTimeInterval(seconds))
            }
        }
        return due
    }

    private func schedule(_ due: Date?) {
        guard due != nextRead || ticks == nil && due != nil else { return }
        ticks?.cancel()
        ticks = nil
        nextRead = due
        guard let due, !hasQuit else { return }
        let wait = Duration.seconds(max(0, due.timeIntervalSince(now())))
        ticks = Task { [weak self, sleep = clock.sleep] in
            try? await sleep(wait, wait / 10)
            guard !Task.isCancelled, let self else { return }
            ticks = nil
            nextRead = nil
            updateClock()
        }
    }
}
