import Observation
import OpenspotCore

@MainActor @Observable
final class SpotLoadedTheme {
    static let shared = SpotLoadedTheme()

    @ObservationIgnored private var theme = Theme()
    private(set) var palette = SpotPalette(Theme())

    func take(_ next: Theme) {
        guard next != theme else { return }
        theme = next
        palette = SpotPalette(next)
    }
}
