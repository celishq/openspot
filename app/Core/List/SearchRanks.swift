import Foundation
import Synchronization

public final class SearchRanks: Sendable {
    @TaskLocal public static var meter: SearchRanks?

    private let counts = Mutex<(all: Int, onMain: Int, weights: Int, dropped: Int)>((0, 0, 0, 0))
    private let gate: (@Sendable (Int) -> Void)?

    public init(gate: (@Sendable (Int) -> Void)? = nil) {
        self.gate = gate
    }

    public var count: Int {
        counts.withLock { $0.all }
    }

    public var countOnMain: Int {
        counts.withLock { $0.onMain }
    }

    public var weights: Int {
        counts.withLock { $0.weights }
    }

    public var dropped: Int {
        counts.withLock { $0.dropped }
    }

    func add() {
        let isMain = Thread.isMainThread
        let number = counts.withLock {
            $0.all += 1
            if isMain { $0.onMain += 1 }
            return $0.all
        }
        gate?(number)
    }

    func addWeights() {
        counts.withLock { $0.weights += 1 }
    }

    func drop() {
        counts.withLock { $0.dropped += 1 }
    }
}
