import Foundation

extension SpotRuns {
    func tick() {
        let time = now()
        var next: TimeInterval?
        for sheet in sheets.values where sheet.spot.read?.waitsForEvents == true {
            if !sheet.isWanted {
                lastClockRead[sheet.spot.id] = nil
            } else if lastClockRead[sheet.spot.id] == nil {
                lastClockRead[sheet.spot.id] = time
                sheet.read(need: .clock, reason: .clock(sheet.spot.read?.seconds))
            }
        }
        for sheet in sheets.values where sheet.isWanted {
            guard let seconds = sheet.spot.read?.seconds else { continue }
            var left = seconds
            if let last = lastClockRead[sheet.spot.id], time.timeIntervalSince(last) < seconds {
                left = seconds - time.timeIntervalSince(last)
            } else {
                lastClockRead[sheet.spot.id] = time
                sheet.read(need: .clock, reason: .clock(sheet.spot.read?.seconds))
            }
            next = min(next ?? left, left)
        }
        nextRead = next
    }

    func updateClock() {
        watchClipboard()
        clock?.cancel()
        clock = nil
        raise(.clock)
        var next = nextRead
        guard isPanelOpen || next != nil else { return }
        clock = Task { [weak self, tickPause] in
            while !Task.isCancelled {
                let isPanelOpen = self?.isPanelOpen ?? false
                let wait = isPanelOpen ? tickPause : max(tickPause, .seconds(next ?? 0))
                try? await Task.sleep(for: wait, tolerance: wait / 10)
                guard !Task.isCancelled, let self else { return }
                raise(.clock)
                next = nextRead
                guard self.isPanelOpen || next != nil else { return }
            }
        }
    }
}
