import Foundation

extension SpotsModel {
    func readWaiting() {
        let spots = entries.filter { $0.role == .card && $0.item == nil && !$0.spot.isBuiltIn }.map(\.spot)
        let (api, runs, stats) = (runs.api, runs, files.stats)
        waitingRead?.cancel()
        waitingRead = Task { [weak self] in
            let found = await Self.waiting(spots, api: api, runs: runs, stats: stats)
            guard let self, !Task.isCancelled, found != waiting else { return }
            waiting = found
        }
    }

    @concurrent
    private nonisolated static func waiting(_ spots: [Spot], api: CommandAPI?, runs: SpotRuns, stats: URL) async -> Set<String> {
        guard let api else { return [] }
        var statuses = api.access.statuses
        if let accesses = api.mac.accesses {
            for access in MacAccess.allCases where access != .automation { statuses[access] = await accesses.status(of: access) }
        }
        let last = runs.usage.lastUses
        let refused = Stats(days: await StatsLog.days(StatsLog.keptDays, runs: runs.usage.keepsDays ? runs : nil, stats: stats), spot: nil).refused
        return Set(spots.filter { spot in
            SpotStanding(spot, statuses: statuses, last: last[spot.id] ?? [:], refused: refused[spot.id] ?? [:]).lacks
        }.map(\.id))
    }

    func openWaiting(_ id: String) -> Bool {
        guard waiting.contains(id) else { return false }
        openSettings(at: .spotOf(id))
        return true
    }
}
