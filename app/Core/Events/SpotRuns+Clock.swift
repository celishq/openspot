import Foundation

/// The clock of timed reads: it reads each wanted script with a number in its `read` when that many seconds have passed.
extension SpotRuns {
    /// Reads each wanted script whose number of seconds has passed, and once each script that waits only for events as it
    /// becomes wanted. Returns the seconds until the next read is due, or nil when no wanted script has a number.
    @discardableResult
    public func tick() -> TimeInterval? {
        let time = now()
        var next: TimeInterval?
        for sheet in sheets.values where sheet.spot.read?.waitsForEvents == true {
            if !sheet.isWanted {
                asked[sheet.spot.id] = nil
            } else if asked[sheet.spot.id] == nil {
                asked[sheet.spot.id] = time
                sheet.read(need: .clock, reason: .timer)
            }
        }
        for sheet in sheets.values where sheet.isWanted {
            guard let seconds = sheet.spot.read?.seconds else { continue }
            var left = seconds
            if let last = asked[sheet.spot.id], time.timeIntervalSince(last) < seconds {
                left = seconds - time.timeIntervalSince(last)
            } else {
                asked[sheet.spot.id] = time
                sheet.read(need: .clock, reason: .timer)
            }
            next = min(next ?? left, left)
        }
        return next
    }

    /// Keeps the timers going while the panel is open, or while something wants a script with a number in its `read`. With
    /// the panel open it looks after each pause, since a card can place a script at any time. With the panel closed it sleeps
    /// until the next read is due, and no less than its pause. A change of what is wanted starts it again.
    func updateClock() {
        watchClipboard()
        clock?.cancel()
        clock = nil
        var next = tick()
        guard isPanelOpen || next != nil else { return }
        clock = Task { [weak self, tickPause] in
            while !Task.isCancelled {
                let isPanelOpen = self?.isPanelOpen ?? false
                try? await Task.sleep(for: isPanelOpen ? tickPause : max(tickPause, .seconds(next ?? 0)))
                guard !Task.isCancelled, let self else { return }
                next = tick()
                guard self.isPanelOpen || next != nil else { return }
            }
        }
    }
}
