import Foundation

extension SpotsModel {
    static let grantKey = "grant"
    static let grantPause: Duration = .seconds(1)
    static let grantTolerance: Duration = .milliseconds(250)

    var settingsSpot: String? {
        entries.first { $0.spot.edits == .settings && $0.spot.isBuiltIn }?.id
    }

    public func grant(_ spot: String, needs: [MacAccess]) -> Bool {
        !needs.isEmpty && start(AccessGrant(spot: spot, steps: needs))
    }

    public func endGrant() {
        guard grant != nil else { return }
        grantWatch?.cancel()
        grantWatch = nil
        grant = nil
        keepGrant()
        readWaiting()
        if let settings = settingsSpot { sheets[settings]?.show(need: .change) }
    }

    public func resumeGrant() async {
        guard let kept = files.defaults.stringArray(forKey: Self.grantKey), let api = runs.api else { return }
        files.defaults.removeObject(forKey: Self.grantKey)
        guard var next = AccessGrant(kept: kept) else { return }
        next.take(await api.access.read(next.steps, from: api.mac, browsers: config.browsers))
        _ = start(next)
    }

    private func start(_ next: AccessGrant) -> Bool {
        guard settingsSpot != nil else { return false }
        grantWatch?.cancel()
        grant = next.step == nil ? nil : next
        keepGrant()
        openSettings(at: "spot/\(next.spot)")
        guard grant != nil else { return true }
        askStep()
        watchGrant()
        return true
    }

    func take(_ statuses: [MacAccess: ReadAccess]) {
        guard var next = grant else { return }
        next.take(statuses)
        guard next != grant else { return }
        grant = next
        let settings = settingsSpot
        if let settings { host.focusWindow(settings) }
        guard next.step != nil else { return endGrant() }
        keepGrant()
        askStep()
        if let settings { sheets[settings]?.show(need: .change) }
    }

    private func keepGrant() {
        if let grant, grant.step?.needsRestart == true {
            files.defaults.set(grant.kept, forKey: Self.grantKey)
        } else {
            files.defaults.removeObject(forKey: Self.grantKey)
        }
    }

    private func askStep() {
        guard let step = grant?.step, let accesses = runs.api?.mac.accesses else { return }
        Task.detached { await accesses.ask(for: step) }
    }

    private func watchGrant() {
        guard let api = runs.api, let steps = grant?.steps else { return }
        let (clock, browsers) = (runs.clock, config.browsers)
        grantWatch = Task.detached { [weak self] in
            while !Task.isCancelled {
                do { try await clock.sleep(Self.grantPause, Self.grantTolerance) } catch { return }
                let statuses = await api.access.read(steps, from: api.mac, browsers: browsers)
                guard !Task.isCancelled else { return }
                await self?.take(statuses)
            }
        }
    }

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
        var statuses: [MacAccess: ReadAccess] = [:]
        if let accesses = api?.mac.accesses {
            for access in MacAccess.allCases where access != .automation { statuses[access] = await accesses.status(of: access) }
        }
        let last = runs.usage.lastUses
        let refused = Stats(days: await StatsLog.days(StatsLog.keptDays, runs: runs.usage.keepsDays ? runs : nil, stats: stats), spot: nil).refused
        return Set(spots.filter { spot in
            [.access, .review].contains(SpotReadiness(spot, statuses: statuses, made: Array((last[spot.id] ?? [:]).keys), refused: refused[spot.id] ?? [:]))
        }.map(\.id))
    }

    func openWaiting(_ id: String) -> Bool {
        guard waiting.contains(id), settingsSpot != nil else { return false }
        openSettings(at: "spot/\(id)")
        return true
    }

    private func openSettings(at place: String) {
        guard let settings = settingsSpot else { return }
        sheets[settings]?.destination = place
        openWindow(settings)
    }
}
