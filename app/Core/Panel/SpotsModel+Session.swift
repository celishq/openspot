import Foundation

extension SpotsModel {
    public static let sessionsSpot = "openspot"
    public static let timelineSpot = "openspot/timeline"

    func showTimeline(about id: String) {
        present(FlowSheet(spot: Self.timelineSpot, route: "about/\(id)", title: entry(id)?.spot.name))
    }

    public func endSession() {
        park.state = .ended
        host.dismiss()
    }

    func parkPanel() {
        waitsBack = false
        park.hide(at: runs.clock.now())
        commitSession()
    }

    func showPanel() {
        if !isShown, park.isParked { park.state = .ended }
        host.show()
    }

    func resumePark() {
        if !window.isWalking { readSessions(older: false) }
        let kept = park
        park = Park()
        guard !kept.startsClean(at: runs.clock.now(), within: restoreTime) else { return startClean() }
        guard kept.isParked else { return }
        guard flow.current.map(restores) ?? true else { return startClean() }
        if let id = openSheetID, let run = sheets[id], !run.isOpen { run.open {} }
        if !flow.pages.isEmpty { startSession() }
        if !searchText.isEmpty { textSelections += 1 }
    }

    private func startClean() {
        commitSession()
        form = nil
        if openSheetID != nil { closeSheet(moving: false) }
        endFlow()
        if !query.isEmpty { takeQuery("") }
    }

    public func noteRun() {
        if session == nil { startSession() }
        session?.ran = true
    }

    func noteFlow(from old: Flow) {
        guard !flow.pages.isEmpty else {
            if !old.pages.isEmpty { commitSession() }
            return
        }
        guard old.pages.isEmpty else {
            session?.place.flow = flow
            return
        }
        if let index = window.index, window.stops[index].place.flow == flow { return }
        commitSession()
        startSession()
        stopWalking()
    }

    func noteQuery() {
        guard !query.isEmpty, flow.pages.isEmpty, session?.place.start == nil else { return }
        if session == nil { startSession() } else { session?.place.query = query }
    }

    private func restores(_ page: FlowSheet) -> Bool {
        sheets[page.spot] != nil && place(ofSheet: page.spot) == .panel && !runs.floating.contains(page.spot)
    }

    func startSession() {
        session = Session(place: SessionPlace(flow: flow, query: query), since: runs.clock.now())
    }

    func commitSession() {
        if let session, session.isWorthKeeping(at: runs.clock.now()) {
            window.add(session.place, at: runs.clock.now())
            keepInTimeline(session.place)
        }
        session = nil
    }

    private func keepInTimeline(_ place: SessionPlace) {
        let page = place.flow.current
        guard page != nil || !place.query.isEmpty else { return }
        let title = page.map { title(of: $0) } ?? place.query
        let icon = page.flatMap { sheets[$0.spot]?.spot.picture } ?? "magnifyingglass"
        let key = page.map { "session:\($0.spot)/\($0.route ?? "")" } ?? "session:text/\(place.query)"
        var draft = Timeline.Draft(kind: .text, values: [title], title: title, icon: icon, key: key)
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
        guard let place = await Task.detached(operation: { timeline.entry(id)?.session }).value, place.flow.current.map(restores) ?? true else { return false }
        asOnePress {
            stopWalking()
            afterShowing({ showPanel() }) { [weak self] in self?.restore(place) }
        }
        return true
    }

    public func stepSession(by steps: Int) -> Bool {
        asOnePress {
            var moved = false
            for _ in 0..<abs(steps) {
                let step = steps < 0 ? (openSheetID != nil && back()) || backSession() : (openSheetID != nil && forward()) || forwardSession()
                guard step else { break }
                moved = true
            }
            return moved
        }
    }

    func backSession() -> Bool {
        if !window.isWalking {
            let shown = SessionPlace(flow: flow, query: query)
            commitSession()
            if window.stops.first?.place.merges(with: shown) == true { _ = window.back() }
        }
        guard let stop = window.back() else {
            guard !window.isWhole else { return false }
            waitsBack = true
            readSessions(older: true)
            return true
        }
        restore(stop.place)
        if window.needsOlder { readSessions(older: true) }
        return true
    }

    func forwardSession() -> Bool {
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
            if older { window.take(older: stops, before: before, isWhole: read.count < size) } else { window.take(newest: stops, isWhole: read.count < size) }
            guard waitsBack else { return }
            waitsBack = false
            if isShown, window.isWalking { _ = asOnePress { backSession() } }
        }
    }

    func stopWalking() {
        waitsBack = false
        window.stopWalking()
    }

    func restore(_ place: SessionPlace) {
        asOnePress {
            endFlow()
            if query != place.query { takeQuery(place.query) }
            guard let page = place.flow.current, restores(page) else {
                if openSheetID != nil { closeSheet(moving: isShown) }
                return
            }
            flow = place.flow
            show(page, moving: isShown)
        }
    }
}
