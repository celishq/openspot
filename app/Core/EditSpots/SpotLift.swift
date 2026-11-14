import Foundation
import Observation

/// How far the pointer has moved the card that the person drags, and where its top left corner lies in the panel's space.
/// It lies apart from the model, so that a move of the pointer redraws only the lifted card.
@MainActor
@Observable
public final class SpotLift {
    public internal(set) var offset: CGSize = .zero
    public internal(set) var origin: CGPoint = .zero

    public init() {}

    nonisolated deinit {}
}
