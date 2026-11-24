import Foundation

extension SpotsModel {
    func spreadContext() {
        contextWatch?.cancel()
        let pause = contextPause
        contextWatch = Task { [weak self] in
            try? await Task.sleep(for: pause, tolerance: pause / 10)
            guard !Task.isCancelled else { return }
            self?.foldContext()
        }
    }

    func endSpread() {
        contextWatch?.cancel()
        contextWatch = nil
    }

    func placeContext(_ motion: PanelMotion?) {
        guard !isContextMoving else { return }
        var next = context
        next.place(spreads: contextWatch != nil)
        guard next != context else { return }
        guard let motion, isShown else {
            context = next
            return
        }
        isContextMoving = true
        change(motion, { context = next }) { [weak self] in
            self?.isContextMoving = false
            self?.placeContext(.edit)
        }
    }

    private func foldContext() {
        endSpread()
        placeContext(.edit)
    }
}
