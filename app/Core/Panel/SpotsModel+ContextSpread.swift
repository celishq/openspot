import Foundation

extension SpotsModel {
    func spreadContext() {
        contextFold.spreads = true
        contextFold.watch?.cancel()
        let pause = contextFold.pause
        contextFold.watch = Task { [weak self] in
            try? await Task.sleep(for: pause, tolerance: pause / 10)
            guard !Task.isCancelled else { return }
            self?.foldContext()
        }
    }

    func endSpread() {
        contextFold.watch?.cancel()
        contextFold.watch = nil
        contextFold.spreads = false
    }

    func resetContextSpread() {
        endSpread()
        contextFold.isMoving = false
        let next = ContextSpread().next(over: context.chips, selected: context.selected, spreads: false)
        if next != contextSpread { contextSpread = next }
    }

    func placeContext(_ motion: PanelMotion?) {
        guard !contextFold.isMoving else { return }
        let next = contextSpread.next(over: context.chips, selected: context.selected, spreads: contextFold.spreads)
        guard next != contextSpread else { return }
        guard let motion, isShown else {
            contextSpread = next
            return
        }
        contextFold.isMoving = true
        change(motion, { contextSpread = next }) { [weak self] in
            self?.contextFold.isMoving = false
            self?.placeContext(.edit)
        }
    }

    private func foldContext() {
        endSpread()
        placeContext(.edit)
    }
}
