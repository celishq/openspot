import Foundation

extension SpotRuns {
    func runSchedule() {
        scheduleWatch.stop()
        guard !hasQuit else { return }
        if !schedule.isRead { schedule.read() }
        let time = now()
        var next: Date?
        var isChanged = false
        var kept = Set<String>()
        for sheet in sheets.values {
            let id = sheet.spot.id
            for line in sheet.spot.triggers.schedule {
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
                    let late = String(max(0, Int(time.timeIntervalSince(due))))
                    sheet.trigger(ScriptEntry.schedule.message([line.text], [late]), key: "\(ScriptEntry.schedule.name).\(line.text)")
                    next = Self.earlier(next, line.next(after: time))
                } else {
                    next = Self.earlier(next, due)
                }
            }
        }
        if sheets.values.contains(where: { !$0.spot.isBuiltIn && $0.spot.host == nil }), schedule.keep(only: kept) { isChanged = true }
        if isChanged { schedule.write() }
        scheduleWatch.wait(until: next, from: time) { [weak self] in self?.runSchedule() }
    }

    private static func earlier(_ one: Date?, _ two: Date?) -> Date? {
        guard let one else { return two }
        guard let two else { return one }
        return min(one, two)
    }
}
