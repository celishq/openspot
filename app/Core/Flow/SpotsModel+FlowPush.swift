import Foundation

extension SpotsModel {
    func pushIn(_ swap: () -> SpotRun?) {
        step(swap)
    }

    func waitPush(moving: Bool) {
        waitingPush = moving
        if !moving { showEdges() }
    }

    func takeWaitingPush(_ swap: () -> Void) -> Bool {
        guard waitingPush else { return false }
        waitingPush = false
        step {
            swap()
            return nil
        }
        return true
    }

    func dropWaitingPush() {
        guard waitingPush else { return }
        waitingPush = false
        showEdges()
        showQueued()
    }

    var isStepping: Bool {
        waitingPush || (flowEdges.from != nil && landedStep != edgeStep)
    }

    func showEdges() {
        edgeStep += 1
        let next = FlowEdges(flow: flow, title: title(of:))
        if next != flowEdges { flowEdges = next }
    }

    private func step(_ swap: () -> SpotRun?) {
        var loading: SpotRun?
        let target = flow
        change(nil) {
            standEdges()
            loading = swap()
        }
        let step = edgeStep
        let move: () -> Void = { [weak self] in
            guard let self else { return }
            host.nextFrame { [weak self] in
                guard let self, step == edgeStep else { return }
                host.change(.flow, { moveEdges(to: target) }, completion: { [weak self] in self?.land(step) }, removal: { [weak self] in self?.settleEdges(step) })
            }
        }
        if let loading { loading.holdPageMotion(start: move) } else { move() }
    }

    private func land(_ step: Int) {
        guard step == edgeStep else { return }
        landedStep = step
        showQueued()
    }

    private func settleEdges(_ step: Int) {
        guard step == edgeStep else { return }
        if flowEdges.settled != flowEdges { change(nil) { flowEdges = flowEdges.settled } }
        showQueued()
    }

    private func showQueued() {
        guard let current = flow.current, current != flowEdges.shown, openSheetID != nil else { return }
        show(current, moving: isShown)
    }

    private func standEdges() {
        edgeStep += 1
        guard flowEdges.shown != nil, let open = openSheetID, let run = sheets[open], let rect = shownSheetRect else { return }
        let page = formRect == nil ? SheetPage(run: run, rect: rect, query: searchText, recording: recording, keyStatus: keys.status) : nil
        flowEdges = flowEdges.standing(at: rect, holding: page, in: flow, title: title(of:))
    }

    private func moveEdges(to target: Flow) {
        flowEdges = flowEdges.moved(to: FlowEdges(flow: target, title: title(of:)))
    }

    private var shownSheetRect: CGRect? {
        formRect ?? openSheetID.flatMap { sheets[$0]?.sheetRect }
    }
}
