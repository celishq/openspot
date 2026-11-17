import Observation
import OpenspotCore

@MainActor @Observable
final class SpotLoadedTheme {
    static let shared = SpotLoadedTheme()

    @ObservationIgnored private var theme = Theme()
    private(set) var palette = SpotPalette(Theme())
    private(set) var layout = 0

    func take(_ next: Theme) {
        guard next != theme else { return }
        theme = next
        palette = SpotPalette(next)
    }

    func layOut(_ next: Theme) {
        SpotTokens.take(next)
        MotionTokens.take(next.motion)
        SpotType.take(next.type)
        SpotBackdropEdge.draw()
        layout += 1
    }
}
