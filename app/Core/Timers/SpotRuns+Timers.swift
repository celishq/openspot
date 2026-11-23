import Foundation

extension SpotRuns {
    public func readTimers() {
        timers.read()
        scheduleTimers()
    }

    func addTimer(at time: Date?, call: SpotTimer.Call, of spot: String) -> Result<String, SpotError> {
        let id = String(UUID().uuidString.prefix(8)).lowercased()
        if let fault = timers.add(SpotTimer(id: id, spot: spot, at: time, action: call.action, inputs: call.inputs)) { return .failure(.fault(fault)) }
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
        timerWatch.stop()
        guard !hasQuit else { return }
        let time = now()
        let due = timers.takeDue(at: time)
        if !due.isEmpty { timers.write() }
        for timer in due {
            guard let action = timer.action else { continue }
            sheets[timer.spot]?.trigger(Message(.press(action), inputs: (timer.inputs ?? []).map { .init(key: $0.name, value: $0.value) }), key: "\(SpotTimer.call).\(timer.id)")
        }
        timerWatch.wait(until: timers.next, from: time) { [weak self] in self?.scheduleTimers() }
    }
}
