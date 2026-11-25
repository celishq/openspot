import Foundation

extension SpotsModel {
    static let openAgain = "Close and open Openspot to see the whole theme."

    public func take(_ theme: Theme) {
        host.paint(theme.colours)
        defer { takenTheme = theme }
        guard isPanelHidden else {
            if theme != takenTheme { toast(ToastNote(words: Self.openAgain)) }
            heldLayout = theme.layout
            return
        }
        lay(theme.layout)
    }

    func widen() {
        guard apply(laidOut) else { return }
        showVisible()
        takePlacements()
        host.widen()
    }

    func lay(_ layout: Theme.Layout) {
        heldLayout = nil
        guard apply(layout) else { return }
        takePlacements()
        host.layOut(laidOut)
    }

    private func apply(_ layout: Theme.Layout) -> Bool {
        let next = layout.with(columns: grid.columns)
        guard next != laidOut else { return false }
        laidOut = next
        SpotTokens.take(next)
        gridScroll = 0
        cardScroll = 0
        for run in runs.sheets.values { run.layOut() }
        return true
    }
}
