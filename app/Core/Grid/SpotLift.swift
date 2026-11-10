import Foundation
import Observation

/// How far the pointer has moved the card that the person drags. It lies apart from the model, so that a move of the
/// pointer redraws only the lifted card.
@MainActor
@Observable
public final class SpotLift {
    public internal(set) var offset: CGSize = .zero

    public init() {}

    nonisolated deinit {}
}
