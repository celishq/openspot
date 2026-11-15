import Foundation
import Synchronization

public final class ScanWork: Sendable {
    @TaskLocal public static var meter: ScanWork?

    private let counts = Mutex<(parses: Int, stats: Int, statsOnMain: Int)>((0, 0, 0))

    public init() {}

    public var parses: Int {
        counts.withLock { $0.parses }
    }

    public var stats: Int {
        counts.withLock { $0.stats }
    }

    public var statsOnMain: Int {
        counts.withLock { $0.statsOnMain }
    }

    func parse() {
        counts.withLock { $0.parses += 1 }
    }

    func stat() {
        let isMain = Thread.isMainThread
        counts.withLock {
            $0.stats += 1
            if isMain { $0.statsOnMain += 1 }
        }
    }
}
