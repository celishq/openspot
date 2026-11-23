import Foundation
import Synchronization

public final class SearchRanks: Sendable {
    @TaskLocal public static var meter: SearchRanks?

    private let counts = Mutex<(all: Int, weights: Int)>((0, 0))

    public init() {}

    public var count: Int {
        counts.withLock { $0.all }
    }

    public var weights: Int {
        counts.withLock { $0.weights }
    }

    func add() {
        counts.withLock { $0.all += 1 }
    }

    func addWeights() {
        counts.withLock { $0.weights += 1 }
    }
}
