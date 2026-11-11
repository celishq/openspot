import Foundation
import Observation

/// Where the panel and the store lie in the panel's window, from its top left corner. In Edit Spots the window grows to hold
/// the store under the panel, and the panel glides to the top by `lift`; `isOut` shows the store.
@MainActor @Observable final class SpotsWindowPlace {
    var panel = CGPoint.zero
    /// The dock's frame, while Edit Spots shows it.
    var dock: CGRect?
    var isOut = false
    /// How far below its place the panel is drawn, while it glides to its place in Edit Spots or back from it.
    var lift: CGFloat = 0

    nonisolated deinit {}
}
