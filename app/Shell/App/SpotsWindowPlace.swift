import Foundation
import Observation

/// Where the center panel lies in the panel's window, right of its side panels.
@MainActor @Observable final class SpotsWindowPlace {
    /// How far the side panels that the window holds reach left of the center panel, which the panel's view lies at.
    var left: CGFloat = 0

    nonisolated deinit {}
}
