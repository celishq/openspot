import Foundation

extension SpotsModel {
    static let grantKey = "grant"
    static let grantPause: Duration = .seconds(1)
    static let grantTolerance: Duration = .milliseconds(250)

    public func grant(_ spot: String?, needs: [MacAccess]) -> Bool {
        !needs.isEmpty && start(AccessGrant(spot: spot, steps: needs))
    }

    public func endGrant() {
        guard grant != nil else { return }
        grantWatch?.cancel()
        grantWatch = nil
        grant = nil
        settingsBook.grant = nil
        keepGrant()
        readWaiting()
        settingsBook.refresh()
    }

    public func resumeGrant() async {
        guard let kept = files.defaults.stringArray(forKey: Self.grantKey), let api = runs.api else { return }
        files.defaults.removeObject(forKey: Self.grantKey)
        guard var next = AccessGrant(kept: kept) else { return }
        next.take(await api.access.read(next.steps, from: api.mac, browsers: config.browsers))
        _ = start(next)
    }

    private func start(_ next: AccessGrant) -> Bool {
        grantWatch?.cancel()
        grant = next.step == nil ? nil : next
        settingsBook.grant = grant
        keepGrant()
        openSettings(at: next.spot.map(SettingsPlace.spotOf) ?? .accessOf(next.steps[0]))
        guard grant != nil else { return true }
        askStep()
        watchGrant()
        return true
    }

    func take(_ statuses: [MacAccess: AccessStatus]) {
        guard var next = grant else { return }
        next.take(statuses)
        guard next != grant else { return }
        grant = next
        settingsBook.grant = next
        host.focusSettings()
        guard next.step != nil else { return endGrant() }
        keepGrant()
        askStep()
        settingsBook.refresh()
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
}
