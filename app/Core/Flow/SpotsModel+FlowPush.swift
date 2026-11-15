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
    }

    func showEdges() {
        edgeStep += 1
        let next = FlowEdges(flow: flow, title: title(of:))
        if next != flowEdges { flowEdges = next }
    }

    private func step(_ swap: () -> SpotRun?) {
        var loading: SpotRun?
        change(nil) {
            standEdges()
            loading = swap()
        }
        let step = edgeStep
        let move = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, step == edgeStep else { return }
                change(.flow, { moveEdges() }) { [weak self] in self?.settleEdges(step) }
            }
        }
        if let loading { loading.holdPageMotion(start: move) } else { move() }
    }

    private func settleEdges(_ step: Int) {
        guard step == edgeStep, flowEdges.settled != flowEdges else { return }
        change(nil) { flowEdges = flowEdges.settled }
    }

    private func standEdges() {
        edgeStep += 1
        guard flowEdges.shown != nil, let open = openList, let run = sheets[open], let rect = shownSheetRect else { return }
        let page = formRect == nil ? SheetPage(run: run, rect: rect, query: searchText) : nil
        flowEdges = flowEdges.standing(at: rect, holding: page, in: flow, title: title(of:))
    }

    private func moveEdges() {
        flowEdges = flowEdges.moved(to: FlowEdges(flow: flow, title: title(of:)))
    }

    private var shownSheetRect: CGRect? {
        formRect ?? openList.flatMap { sheets[$0]?.sheetRect }
    }
}
