import Foundation

extension SpotsModel {
    public func take(_ theme: Theme) {
        guard isPanelHidden else {
            heldTheme = theme
            return
        }
        heldTheme = nil
        let laidOut = laidOutTheme
        guard theme.space != laidOut.space || theme.radius != laidOut.radius || theme.type != laidOut.type || theme.motion != laidOut.motion else { return }
        laidOutTheme = theme
        SpotTokens.take(theme)
        MotionTokens.take(theme.motion)
        takePlacements()
        for run in runs.sheets.values { run.layOut() }
        host.layOut(theme)
    }
}
