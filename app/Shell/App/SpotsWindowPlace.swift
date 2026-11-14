import Foundation
import Observation

@MainActor @Observable final class SpotsWindowPlace {
    var left: CGFloat = 0

    nonisolated deinit {}
}
