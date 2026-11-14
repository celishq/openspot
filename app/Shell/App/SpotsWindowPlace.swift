import Foundation
import Observation

/// Where the panel and the store lie in the panel's window, from its top left corner. In Edit Spots the window grows to hold
/// the store under the panel, and the panel glides to the top by `lift`; `isOut` shows the store.
@MainActor @Observable final class SpotsWindowPlace {
    /// Where the panel with its side panels lies.
    var panel = CGPoint.zero
    /// How far the side panels that the window holds reach left of the center panel, which the panel's view lies at.
    var left: CGFloat = 0
    /// The dock's frame, while Edit Spots shows it.
    var dock: CGRect?
    /// The size of the store once Edit Spots has built it. The store stays built outside the window while Edit Spots is off.
    var storeSize: CGSize?
    var isOut = false
    /// How far below its place the panel is drawn, while it glides to its place in Edit Spots or back from it.
    var lift: CGFloat = 0

    nonisolated deinit {}
}
