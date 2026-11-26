import Foundation
import Observation

@MainActor @Observable final class SpotsWindowPlace {
    var left: CGFloat = 0
    var top: CGFloat = 0
    var screen: CGSize?

    nonisolated deinit {}
}
