import Foundation

extension SpotsModel {
    public static let sessionsSpot = "openspot"
    public static let timelineSpot = "openspot/timeline"

    func showTimeline(about id: String) {
        present(FlowSheet(spot: Self.timelineSpot, route: "about/\(id)", title: entry(id)?.spot.name))
    }

    public func endSession() {
        session.ends = true
        host.dismiss()
    }

    func parkSession() {
        session.hide(at: runs.clock.now())
        commitVisit()
    }

    func leaveParkedSession() {
        guard !isShown, session.parked != nil else { return }
        session.parked = nil
        session.isEnded = true
    }

    func resumeSession() {
        if !window.isWalking { readSessions(older: false) }
        let kept = session
        session = PanelSession(visit: kept.visit)
        guard !kept.startsClean(at: runs.clock.now(), within: restoreTime) else { return startClean() }
        guard kept.parked != nil else { return }
        if let id = openSheetID, let run = sheets[id], !run.isOpen { run.open {} }
        if !flow.pages.isEmpty {
            isRestoringVisit = true
            startVisit()
            isRestoringVisit = false
        }
        if !searchText.isEmpty { textSelections += 1 }
    }

    private func startClean() {
        commitVisit()
        form = nil
        if openSheetID != nil { closeSheet(moving: false) }
        endFlow()
        if !query.isEmpty { takeQuery("") }
    }

    public func noteRun() {
        if session.visit == nil { startVisit() }
        session.visit?.ran = true
    }

    func noteFlow(from old: Flow) {
        guard !flow.pages.isEmpty else {
            if !old.pages.isEmpty { commitVisit() }
            return
        }
        guard old.pages.isEmpty else {
            session.visit?.place.flow = flow
            return
        }
        commitVisit()
        startVisit()
        if !isRestoringVisit { window.stopWalking() }
    }

    func noteQuery() {
        guard !query.isEmpty, flow.pages.isEmpty, session.visit?.place.start == nil else { return }
        if session.visit == nil { startVisit() } else { session.visit?.place.query = query }
    }

    private func restores(_ page: FlowSheet) -> Bool {
        sheets[page.spot] != nil && place(ofSheet: page.spot) == .panel && !runs.floating.contains(page.spot)
    }

    func startVisit() {
        session.visit = PanelSession.Visit(place: SessionPlace(flow: flow, query: query), since: runs.clock.now(), isRestored: isRestoringVisit)
    }

    func commitVisit() {
        if let visit = session.visit, visit.isWorthKeeping(at: runs.clock.now()) {
            window.add(visit.place, at: runs.clock.now())
            keepInTimeline(visit.place)
        }
        session.visit = nil
    }

    private func keepInTimeline(_ place: SessionPlace) {
        guard let page = place.flow.current, let spot = sheets[page.spot]?.spot else { return }
        let title = title(of: page)
        var draft = Timeline.Draft(kind: .text, values: [title], title: title, icon: spot.picture, key: "visit:\(page.spot)/\(page.route ?? "")")
        draft.session = place
        let runs = runs
        let timeline = runs.timeline
        let now = runs.clock.now()
        let owner = Self.sessionsSpot
        Task.detached {
            _ = try? timeline.add(draft, of: owner, at: now)
            await runs.timelineChanged(owner, by: nil)
        }
    }

    public func openSession(_ id: String) async -> Bool {
        let timeline = runs.timeline
        guard let place = await Task.detached(operation: { timeline.entry(id)?.session }).value, let page = place.flow.current, restores(page) else { return false }
        asOnePress {
            leaveParkedSession()
            window.stopWalking()
            afterShowing({ host.show() }) { [weak self] in self?.restore(place) }
        }
        return true
    }

    public func stepSession(by steps: Int) -> Bool {
        asOnePress {
            var moved = false
            for _ in 0..<abs(steps) {
                let step = steps < 0 ? (openSheetID != nil && back()) || backVisit() : (openSheetID != nil && forward()) || forwardVisit()
                guard step else { break }
                moved = true
            }
            return moved
        }
    }

    func handleTrailKey(_ key: ActionKey) -> Bool? {
        switch FlowKey(key) {
        case .back: backVisit()
        case .forward: forwardVisit()
        default: nil
        }
    }

    func backVisit() -> Bool {
        if !window.isWalking {
            let shown = SessionPlace(flow: flow, query: query)
            commitVisit()
            if window.stops.first?.place.merges(with: shown) == true { _ = window.back() }
        }
        guard let stop = window.back() else {
            guard !window.isWhole else { return false }
            waitingBacks += 1
            readSessions(older: true)
            return true
        }
        restore(stop.place)
        if window.needsOlder { readSessions(older: true) }
        return true
    }

    func forwardVisit() -> Bool {
        switch window.forward() {
        case nil: return false
        case .present: if openSheetID != nil { closeSheet(moving: isShown) }
        case .stop(let stop): restore(stop.place)
        }
        return true
    }

    func readSessions(older: Bool) {
        guard !isReadingSessions else { return }
        isReadingSessions = true
        let timeline = runs.timeline
        let owner = Self.sessionsSpot
        let before = older ? window.oldest : nil
        let size = SessionWindow.size
        Task { [weak self] in
            let read = await Task.detached { timeline.sessions(of: owner, before: before, limit: size) }.value
            guard let self else { return }
            isReadingSessions = false
            let stops = read.compactMap { entry in entry.session.map { SessionWindow.Stop(place: $0, at: entry.at) } }
            if older { window.take(older: stops, isWhole: read.count < size) } else { window.take(newest: stops, isWhole: read.count < size) }
            guard waitingBacks > 0 else { return }
            waitingBacks -= 1
            _ = asOnePress { backVisit() }
        }
    }

    func restore(_ place: SessionPlace) {
        asOnePress {
            isRestoringVisit = true
            defer { isRestoringVisit = false }
            endFlow()
            if query != place.query { takeQuery(place.query) }
            guard let page = place.flow.current, restores(page) else {
                if openSheetID != nil { closeSheet(moving: isShown) }
                startVisit()
                return
            }
            flow = place.flow
            show(page, moving: isShown)
        }
    }
}
