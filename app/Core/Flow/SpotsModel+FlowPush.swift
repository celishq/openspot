import Foundation

extension SpotsModel {
    func pushIn(_ change: @escaping () -> Void) {
        beginStep()
        offerSwap(change)
    }

    func waitPush(moving: Bool) {
        waitingPush = moving
        if moving { beginStep() } else { showEdges() }
    }

    func takeWaitingPush(_ swap: @escaping () -> Void) -> Bool {
        guard waitingPush else { return false }
        waitingPush = false
        offerSwap(swap)
        return true
    }

    func dropWaitingPush() {
        guard waitingPush else { return }
        waitingPush = false
        offerSwap {}
    }

    func showEdges() {
        edgeStep += 1
        let next = FlowEdges(flow: flow, title: title(of:))
        if next != flowEdges { flowEdges = next }
    }

    private func beginStep() {
        if let swap = stepSwap {
            stepSwap = nil
            change(nil, swap)
        }
        change(nil) { standEdges() }
        isStepFaded = false
        let step = edgeStep
        DispatchQueue.main.async { [weak self] in
            guard let self, step == edgeStep else { return }
            change(.flow) { moveEdges() }
            change(.fadeOut, { flowEdges.showsContent = false }) { [weak self] in
                guard let self, step == edgeStep else { return }
                isStepFaded = true
                swapStep(step)
            }
        }
    }

    private func offerSwap(_ swap: @escaping () -> Void) {
        stepSwap = swap
        swapStep(edgeStep)
    }

    private func swapStep(_ step: Int) {
        guard isStepFaded, let swap = stepSwap else { return }
        stepSwap = nil
        change(.flow) {
            swap()
            flowEdges.isSwapped = true
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, step == edgeStep else { return }
            change(.fade, { flowEdges.showsContent = true }) { [weak self] in self?.settleEdges(step) }
        }
    }

    private func settleEdges(_ step: Int) {
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
