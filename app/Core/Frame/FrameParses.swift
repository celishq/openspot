import Foundation
import Synchronization

public final class FrameParses: Sendable {
    @TaskLocal public static var meter: FrameParses?

    private let counts = Mutex<(all: Int, onMain: Int)>((0, 0))

    public init() {}

    public var count: Int {
        counts.withLock { $0.all }
    }

    public var countOnMain: Int {
        counts.withLock { $0.onMain }
    }

    func add() {
        let isMain = Thread.isMainThread
        counts.withLock {
            $0.all += 1
            if isMain { $0.onMain += 1 }
        }
    }
}
