import Foundation

/// What each spot cost since the app started: its calls, their time, the CPU time of its processes, its wakeups and its
/// last fault (G1). It only records what already happens, in memory, and reads a process that still runs when asked.
public final class SpotUsage: @unchecked Sendable {
    /// The count of one spot.
    public struct Count: Equatable, Sendable {
        public var name: String?
        public var calls = 0
        /// The wall time of all its calls, in seconds.
        public var seconds: TimeInterval = 0
        public var time = ProcessTime.zero
        public var fault: String?

        /// The CPU time of its processes, in seconds.
        public var cpu: TimeInterval {
            time.cpu
        }
    }

    private let lock = NSLock()
    private var ended: [String: Count] = [:]
    /// Each process that has not ended, with the ID of its spot.
    private var live: [ObjectIdentifier: (spot: String, process: ScriptProcess)] = [:]

    public init() {}

    /// The count of each spot by its ID, with the time so far of each process that runs.
    public var counts: [String: Count] {
        lock.withLock {
            var counts = ended
            for (spot, process) in live.values {
                counts[spot, default: Count()].time = counts[spot, default: Count()].time + process.time
            }
            return counts
        }
    }

    /// Counts the time of a process of a spot, while it runs and once it ends. Call it before the process starts.
    func track(_ process: ScriptProcess, of spot: String) {
        let key = ObjectIdentifier(process)
        lock.withLock { live[key] = (spot, process) }
        process.onExit { [weak self] time in
            guard let self else { return }
            lock.withLock {
                guard let spot = live.removeValue(forKey: key)?.spot else { return }
                ended[spot, default: Count()].time = ended[spot, default: Count()].time + time
            }
        }
    }

    /// Counts a call that ended after this many seconds.
    func called(_ spot: String, name: String, seconds: TimeInterval) {
        lock.withLock {
            ended[spot, default: Count()].name = name
            ended[spot, default: Count()].calls += 1
            ended[spot, default: Count()].seconds += seconds
        }
    }

    /// Keeps the fault that the person was told, as the last of this spot.
    func failed(_ spot: String, name: String, fault: String) {
        lock.withLock {
            ended[spot, default: Count()].name = name
            ended[spot, default: Count()].fault = fault
        }
    }
}
