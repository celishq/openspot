import Foundation

extension SpotRuns {
    func script(of spot: Spot) -> InlineScript {
        let stamp = stamps[spot.id]
        if let kept = loaded[spot.id], kept.stamp == stamp, !kept.script.hasEnded { return kept.script }
        loaded[spot.id]?.script.end()
        let id = spot.id
        let idle = max(inlineIdle, (spot.read?.seconds ?? 0) * 1.5)
        let script = InlineScript(spot: spot, api: api, tokens: tokens, sandbox: sandbox(for: spot), limit: readLimit, idle: idle, base: environment) { [usage] seconds in
            usage.add(ProcessTime(cpu: seconds, wakeups: 0), to: id, at: usage.now())
        }
        loaded[id] = (stamp, script)
        return script
    }

    func sandbox(for spot: Spot) -> Set<SpotUse>? {
        spot.isRestricted ? spot.uses : nil
    }

    func dropScript(of id: String) {
        loaded.removeValue(forKey: id)?.script.end()
    }
}
