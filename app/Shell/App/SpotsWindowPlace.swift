import Foundation
import Observation

/// Where the panel and the dock lie in the panel's window, from its top left corner. In Edit Spots the window grows to hold
/// the dock under the panel, and the panel keeps its place on the screen.
@MainActor @Observable final class SpotsWindowPlace {
    var panel = CGPoint.zero
    /// The dock's frame, while Edit Spots shows it.
    var dock: CGRect?

    nonisolated deinit {}
}
