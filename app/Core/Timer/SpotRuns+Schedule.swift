import Foundation

extension SpotRuns {
    func runSchedule() {
        scheduleWatch?.cancel()
        scheduleWatch = nil
        guard !hasQuit else { return }
        if !schedule.isRead { schedule.read() }
        let time = now()
        var next: Date?
        var isChanged = false
        var kept = Set<String>()
        for sheet in sheets.values {
            let id = sheet.spot.id
            for line in sheet.spot.triggers?.schedule ?? [] {
                kept.insert(SpotSchedule.key(line, of: id))
                guard let last = schedule.last(line, of: id) else {
                    schedule.ran(line, of: id, at: time)
                    isChanged = true
                    next = Self.earlier(next, line.next(after: time))
                    continue
                }
                guard let due = line.next(after: last) else { continue }
                if due <= time {
                    schedule.ran(line, of: id, at: time)
                    isChanged = true
                    sheet.scheduled(line, late: Int(time.timeIntervalSince(due)))
                    next = Self.earlier(next, line.next(after: time))
                } else {
                    next = Self.earlier(next, due)
                }
            }
        }
        if schedule.keep(only: kept) { isChanged = true }
        if isChanged { schedule.write() }
        guard let next else { return }
        let wait = Duration.seconds(max(0, next.timeIntervalSince(time)))
        scheduleWatch = Task { [weak self, sleep = clock.sleep] in
            try? await sleep(wait, min(wait / 10, .seconds(1)))
            guard !Task.isCancelled, let self else { return }
            runSchedule()
        }
    }

    private static func earlier(_ one: Date?, _ two: Date?) -> Date? {
        guard let one else { return two }
        guard let two else { return one }
        return min(one, two)
    }
}
