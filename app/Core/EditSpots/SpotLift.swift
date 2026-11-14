import Foundation
import Observation

@MainActor
@Observable
public final class SpotLift {
    public internal(set) var offset: CGSize = .zero
    public internal(set) var origin: CGPoint = .zero

    public init() {}

    nonisolated deinit {}
}
