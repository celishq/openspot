import Foundation

/// The push motion of the flow: the content of the sheet lies `pushOffset` to the side that the next sheet comes from, and
/// moves to its place on the next turn, on the push curve. A sheet of another spot waits for its sheet to be ready before
/// it starts.
extension SpotsModel {
    /// Lays the content at `side` while `change` shows the next sheet, and moves it to its place on the next turn.
    func pushIn(from side: Double, _ change: () -> Void) {
        self.change(nil) {
            change()
            pushOffset = side * MotionTokens.pushDistance
        }
        settlePush()
    }

    /// Keeps the side of a push until the sheet of its spot is ready, or drops it when the sheet does not move.
    func waitPush(from side: Double?) {
        waitingPush = side
    }

    /// Starts the push that waits for this sheet, in the change that shows it.
    func startWaitingPush() {
        guard let side = waitingPush else { return }
        waitingPush = nil
        pushOffset = side * MotionTokens.pushDistance
        settlePush()
    }

    func dropWaitingPush() {
        waitingPush = nil
    }

    /// Moves the content of the sheet to its place on the next turn, so that the push has a start.
    private func settlePush() {
        DispatchQueue.main.async { [weak self] in
            self?.change(.push) { self?.pushOffset = 0 }
        }
    }
}
