import Foundation

extension SpotsModel {
    func pushIn(_ change: @escaping () -> Void) {
        self.change(nil) { standEdges() }
        let step = edgeStep
        DispatchQueue.main.async { [weak self] in
            self?.change(.flow, {
                change()
                self?.moveEdges()
            }) { self?.settleEdges(step) }
        }
    }

    func waitPush(moving: Bool) {
        waitingPush = moving
        if moving { change(nil) { standEdges() } } else { showEdges() }
    }

    func startWaitingPush() {
        guard waitingPush else { return }
        waitingPush = false
        moveEdges()
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

    func settleEdges(_ step: Int) {
        guard step == edgeStep, flowEdges.settled != flowEdges else { return }
        change(nil) { flowEdges = flowEdges.settled }
    }

    private func standEdges() {
        edgeStep += 1
        guard flowEdges.shown != nil, let rect = shownSheetRect else { return }
        flowEdges = flowEdges.standing(at: rect, in: flow, title: title(of:))
    }

    private func moveEdges() {
        flowEdges = flowEdges.moved(to: FlowEdges(flow: flow, title: title(of:)))
    }

    private var shownSheetRect: CGRect? {
        formRect ?? openList.flatMap { sheets[$0]?.sheetRect }
    }
}
