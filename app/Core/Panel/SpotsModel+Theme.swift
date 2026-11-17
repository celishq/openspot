import Foundation

extension SpotsModel {
    public func take(_ theme: Theme) {
        host.paint(theme.look)
        guard isPanelHidden else {
            heldLayout = theme.layout
            return
        }
        lay(theme.layout)
    }

    func lay(_ layout: Theme.Layout) {
        heldLayout = nil
        guard layout != laidOut else { return }
        laidOut = layout
        gridScroll = 0
        cardScroll = 0
        SpotTokens.take(layout)
        takePlacements()
        for run in runs.sheets.values { run.layOut() }
        host.layOut(layout)
    }
}
