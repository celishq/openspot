import Foundation

extension SpotRuns {
    public func readTimers() {
        timers.read()
        scheduleTimers()
    }

    func addTimer(at time: Date, value: String?, of spot: String) -> Result<String, SpotError> {
        let id = String(UUID().uuidString.prefix(8)).lowercased()
        if let fault = timers.add(SpotTimer(id: id, spot: spot, at: time, value: value)) { return .failure(.fault(fault)) }
        timers.write()
        scheduleTimers()
        return .success(id)
    }

    func removeTimer(_ id: String, of spot: String) -> Bool {
        guard timers.remove(id, of: spot) else { return false }
        timers.write()
        scheduleTimers()
        return true
    }

    func timers(of spot: String) -> [SpotTimer] {
        timers.of(spot)
    }

    func scheduleTimers() {
        timerWatch?.cancel()
        timerWatch = nil
        guard !hasQuit else { return }
        let time = now()
        let due = timers.takeDue(at: time)
        if !due.isEmpty { timers.write() }
        for timer in due {
            sheets[timer.spot]?.due(timer, late: Int(time.timeIntervalSince(timer.at)))
        }
        guard let next = timers.next else { return }
        let wait = Duration.seconds(max(0, next.timeIntervalSince(time)))
        timerWatch = Task { [weak self, sleep = clock.sleep] in
            try? await sleep(wait, min(wait / 10, .seconds(1)))
            guard !Task.isCancelled, let self else { return }
            scheduleTimers()
        }
    }
}
