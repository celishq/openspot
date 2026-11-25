import Foundation

extension SpotRuns {
    func mode(of spot: Spot) -> any ScriptMode.Type {
        if spot.holdsSettings, spot.settingsSheet != nil { return SettingsMode.self }
        if spot.host != nil { return HostMode.self }
        return switch spot.mode {
        case .inline: InlineMode.self
        case .stay: StayMode.self
        case .once: OnceMode.self
        }
    }

    func script(of spot: Spot) -> InlineScript {
        let stamp = stamps[spot.id]
        if let kept = loaded[spot.id], kept.stamp == stamp, !kept.script.hasEnded { return kept.script }
        loaded[spot.id]?.script.end()
        let id = spot.id
        let idle = max(inlineIdle, TimeInterval(spot.triggers.every ?? 0) * 1.5)
        let bound = Dictionary(spot.bindings.compactMap { binding in sheets[binding.spot].map { (binding.name, $0.spot) } }) { first, _ in first }
        let env = SpotEnv(spot: spot, cache: cache, fetch: fetch, isCareful: isCareful, locale: api?.mac.locale() ?? .autoupdatingCurrent, runs: self)
        let script = InlineScript(spot: spot, api: api, callers: callers, careful: isCareful ? spot.uses : nil, limit: showLimit, idle: idle, bound: bound, base: environment, env: env, clock: clock) { [usage] seconds in
            usage.add(ProcessTime(cpu: seconds, wakeups: 0), to: id, at: usage.now())
        }
        loaded[id] = (stamp, script)
        return script
    }

    func dropScript(of id: String) {
        loaded.removeValue(forKey: id)?.script.end()
    }
}
