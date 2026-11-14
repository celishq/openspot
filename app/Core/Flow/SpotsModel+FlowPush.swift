import Foundation

extension SpotsModel {
    func pushIn(from side: Double, _ change: () -> Void) {
        self.change(nil) {
            change()
            pushOffset = side * MotionTokens.pushDistance
        }
        settlePush()
    }

    func waitPush(from side: Double?) {
        waitingPush = side
    }

    func startWaitingPush() {
        guard let side = waitingPush else { return }
        waitingPush = nil
        pushOffset = side * MotionTokens.pushDistance
        settlePush()
    }

    func dropWaitingPush() {
        waitingPush = nil
    }

    private func settlePush() {
        DispatchQueue.main.async { [weak self] in
            self?.change(.push) { self?.pushOffset = 0 }
        }
    }
}
