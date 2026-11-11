import Observation
import SwiftUI

/// How far each end of the grid fades as it scrolls. Only the masks that draw the fade read it, so that a scroll near an end
/// reruns no other view.
@MainActor
@Observable
final class SpotScrollFade {
    var edges = SpotScrollEdges()
}
