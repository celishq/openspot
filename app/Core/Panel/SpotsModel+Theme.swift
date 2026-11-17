import Foundation

extension SpotsModel {
    static let openAgain = "Close and open Openspot to see the whole theme."

    public func take(_ theme: Theme) {
        host.paint(theme.colours)
        defer { takenTheme = theme }
        guard isPanelHidden else {
            if theme != takenTheme { host.confirm(Self.openAgain) }
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
