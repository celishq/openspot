import Foundation

extension SpotsModel {
    static let openAgain = "Close and open Openspot to see the whole theme."

    public func take(_ theme: Theme) {
        host.paint(theme.colours)
        defer { takenTheme = theme }
        guard isPanelHidden else {
            if theme != takenTheme { toast(ToastNote(words: Self.openAgain)) }
            heldLayout = theme.layout.with(columns: grid.columns)
            return
        }
        lay(theme.layout.with(columns: grid.columns))
    }

    func widen() {
        heldLayout = heldLayout?.with(columns: grid.columns)
        laidOut = laidOut.with(columns: grid.columns)
        SpotTokens.take(laidOut)
        gridScroll = 0
        cardScroll = 0
        for run in runs.sheets.values { run.layOut() }
        showVisible()
        takePlacements()
        host.widen()
    }

    func lay(_ layout: Theme.Layout) {
        heldLayout = nil
        guard layout != laidOut else { return }
        laidOut = layout
        SpotTokens.take(layout)
        gridScroll = 0
        cardScroll = 0
        takePlacements()
        for run in runs.sheets.values { run.layOut() }
        host.layOut(layout)
    }
}
