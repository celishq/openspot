import Foundation

extension SpotsModel {
    public func endSession() {
        session.ends = true
        host.dismiss()
    }

    func parkSession() {
        session.hide(flow: flow, sheetQuery: openSheet?.query ?? "", at: runs.clock.now())
    }

    func leaveParkedSession() {
        guard !isShown else { return }
        session.parked = nil
        commitVisit()
    }

    func resumeSession() {
        let kept = session
        session = PanelSession(visit: kept.visit)
        guard !kept.startsClean(at: runs.clock.now()) else { return startClean() }
        guard let parked = kept.parked else { return }
        if openSheetID == nil, flow.current == nil, let page = parked.flow.current, sheets[page.spot] != nil {
            holdsVisit = true
            flow = parked.flow
            holdsVisit = false
            show(page, moving: false)
            if !parked.sheetQuery.isEmpty { sheets[page.spot]?.search(parked.sheetQuery) }
        }
        if !searchText.isEmpty { textSelections += 1 }
    }

    private func startClean() {
        commitVisit()
        if openSheetID != nil { closeSheet(moving: false) }
        endFlow()
        if !query.isEmpty { takeQuery("") }
    }

    public func noteRun() {
        if session.visit == nil { startVisit() }
        session.visit?.ran = true
    }

    func noteFlow(from old: Flow) {
        guard !holdsVisit, !flow.pages.isEmpty else { return }
        guard old.pages.isEmpty else {
            session.visit?.place.flow = flow
            return
        }
        commitVisit()
        startVisit()
        if !isRestoringVisit { trail.stopWalking() }
    }

    func noteQuery() {
        guard !holdsVisit, !query.isEmpty, flow.pages.isEmpty, session.visit?.place.start == nil else { return }
        if session.visit == nil { startVisit() } else { session.visit?.place.query = query }
    }

    private func startVisit() {
        session.visit = PanelSession.Visit(place: SessionTrail.Place(flow: flow, query: query), since: runs.clock.now(), isRestored: isRestoringVisit)
    }

    func commitVisit() {
        if let visit = session.visit, visit.isWorthKeeping(at: runs.clock.now()) { trail.add(visit.place) }
        session.visit = nil
    }

    func handleTrailKey(_ key: ActionKey) -> Bool? {
        switch FlowKey(key) {
        case .back: backVisit()
        case .forward: forwardVisit()
        default: nil
        }
    }

    func backVisit() -> Bool {
        if !trail.isWalking {
            let shown = flow.pages.first
            commitVisit()
            if shown != nil, trail.places.last?.start == shown { _ = trail.back() }
        }
        guard let place = trail.back() else { return false }
        restore(place)
        return true
    }

    func forwardVisit() -> Bool {
        guard trail.isWalking else { return false }
        guard let place = trail.forward() else {
            if openSheetID != nil { closeSheet(moving: isShown) }
            return true
        }
        restore(place)
        return true
    }

    private func restore(_ place: SessionTrail.Place) {
        asOnePress {
            isRestoringVisit = true
            defer { isRestoringVisit = false }
            endFlow()
            if query != place.query { takeQuery(place.query) }
            guard let page = place.flow.current, sheets[page.spot] != nil else {
                if openSheetID != nil { closeSheet(moving: isShown) }
                startVisit()
                return
            }
            flow = place.flow
            show(page, moving: isShown)
        }
    }
}
