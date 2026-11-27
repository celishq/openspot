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
        if !isShown { session.parked = nil }
    }

    func resumeSession() {
        let kept = session
        session = PanelSession()
        guard !kept.startsClean(at: runs.clock.now()) else { return startClean() }
        guard let parked = kept.parked else { return }
        if openSheetID == nil, flow.current == nil, let page = parked.flow.current, sheets[page.spot] != nil {
            flow = parked.flow
            show(page, moving: false)
            if !parked.sheetQuery.isEmpty { sheets[page.spot]?.search(parked.sheetQuery) }
        }
        if !searchText.isEmpty { textSelections += 1 }
    }

    private func startClean() {
        if openSheetID != nil { closeSheet(moving: false) }
        endFlow()
        if !query.isEmpty { takeQuery("") }
    }
}
