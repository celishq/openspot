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

        /// Its CPU time, its calls and the time of each call on average, in words.
        var detail: String {
            let cpu = "\(Self.words(time.cpu)) CPU"
            guard calls > 0 else { return cpu }
            return "\(cpu) · \(calls) \(calls == 1 ? "call" : "calls") · \(Self.words(seconds / Double(calls))) each"
        }

        private static func words(_ seconds: TimeInterval) -> String {
            seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
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
            guard let self, let spot = lock.withLock({ live.removeValue(forKey: key)?.spot }) else { return }
            add(time, to: spot)
        }
    }

    /// Adds the time of an ended process to a spot.
    func add(_ time: ProcessTime, to spot: String) {
        lock.withLock { ended[spot, default: Count()].time = ended[spot, default: Count()].time + time }
    }

    /// Counts a call that ended after this many seconds.
    func called(_ spot: String, name: String, seconds: TimeInterval) {
        lock.withLock {
            ended[spot, default: Count()].name = name
            ended[spot, default: Count()].calls += 1
            ended[spot, default: Count()].seconds += seconds
        }
    }

    /// What `openspot spot stats` prints: a row for each spot, the most CPU time first, with its numbers as fields.
    public var text: String {
        counts.sorted { ($0.value.cpu, $1.key) > ($1.value.cpu, $0.key) }.map { id, count in
            var lines = [
                "row=\(id)",
                "title=\(Self.escaped(count.name ?? id))",
                "detail=\(count.detail)",
                "cpu=\(String(format: "%.3f", count.cpu))",
                "calls=\(count.calls)",
                "seconds=\(String(format: "%.3f", count.seconds))",
                "wakeups=\(count.time.wakeups)",
            ]
            if let fault = count.fault { lines += ["fault=\(Self.escaped(fault))", "tone=bad"] }
            return lines.map { $0 + "\n" }.joined() + "\n"
        }.joined()
    }

    /// Keeps the fault that the person was told, as the last of this spot.
    func failed(_ spot: String, name: String, fault: String) {
        lock.withLock {
            ended[spot, default: Count()].name = name
            ended[spot, default: Count()].fault = fault
        }
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
    }
}
