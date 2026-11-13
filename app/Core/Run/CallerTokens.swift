import Foundation

/// The record of each process and inline link of a spot that runs, which marks its calls of `openspot` as the spot's (protocol: Trust).
/// A call comes from the process group that Openspot started for the spot, or else carries the spot's token. The record
/// keeps the reason of the call that runs, and outlives the first process of its group while a child of it still runs. A
/// call from no known group and with no known token is the person's.
public final class CallerTokens: @unchecked Sendable {
    /// The spot that a token stands for.
    public struct Caller: Equatable, Sendable {
        public let id: String
        public let name: String
        public let uses: Set<SpotUse>
        /// Whether the spot comes with the app, such as Settings.
        public var isBuiltIn = false
        /// The folder of its files inside the data of the app, or nil for a caller with none.
        public var dataName: String?

        public var reachesAccountKey: Bool {
            SpotUse.reachesAccountKey(uses, isBuiltIn: isBuiltIn)
        }
    }

    /// One token: its spot, the reason of its call, and the process group that it stands for, with the start of the
    /// group's first process.
    private struct Record {
        let caller: Caller
        var reason: String?
        var group: pid_t?
        var start: UInt64 = 0
        var hasEnded = false
    }

    public static let variable = "OPENSPOT_TOKEN"
    private static let reason = "OPENSPOT_REASON"

    private let lock = NSLock()
    private var records: [String: Record] = [:]
    private var groups: [pid_t: String] = [:]
    private var careful = false

    /// The token that stands for a process in a sandbox that no spot's group or token names, while Careful mode is on.
    private static let sandboxed = "sandboxed"
    /// `sandbox_check`, which the system exports with no public header, and which says whether a process runs in a sandbox.
    private static let sandboxCheck: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32)? =
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sandbox_check").map { unsafeBitCast($0, to: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32).self) }

    /// Whether a process runs in a sandbox, such as a spot's in Careful mode or an agent's of its own.
    static func isSandboxed(_ process: pid_t) -> Bool {
        sandboxCheck?(process, nil, 0) == 1
    }

    /// Whether a process runs in a sandbox and this one does not, so that work for it here would leave its sandbox.
    static func isSandboxedApart(_ process: pid_t) -> Bool {
        isSandboxed(process) && !isSandboxed(getpid())
    }

    public init() {
        records[Self.sandboxed] = Record(caller: Caller(id: "", name: "A sandboxed process", uses: []))
    }

    /// A new random token that stands for the spot until its release, with the reason of its call.
    func issue(for spot: Spot, reason: String? = nil) -> String {
        var random = SystemRandomNumberGenerator()
        let token = String(format: "%016llx%016llx", random.next() as UInt64, random.next() as UInt64)
        lock.withLock { records[token] = Record(caller: Caller(id: spot.id, name: spot.name, uses: spot.uses, isBuiltIn: spot.isBuiltIn, dataName: spot.dataName), reason: reason) }
        return token
    }

    /// Whether Careful mode is on, in which a spot's call of a use that its header does not name is refused (protocol: Trust).
    public var isCareful: Bool {
        get { lock.withLock { careful } }
        set { lock.withLock { careful = newValue } }
    }

    /// Ties a token to the process group that its process started, and lets go of each ended group.
    func enter(_ group: pid_t, token: String) {
        let start = Self.start(of: group)
        lock.withLock {
            for (other, held) in groups where records[held]?.hasEnded == true && kill(-other, 0) != 0 {
                groups[other] = nil
                records[held] = nil
            }
            guard records[token] != nil else { return }
            records[token]?.group = group
            records[token]?.start = start
            groups[group] = token
        }
    }

    /// Sets the reason of the call that a token's process runs now, or nil when it runs none that reads.
    func setReason(_ reason: String?, of token: String) {
        lock.withLock { records[token]?.reason = reason }
    }

    /// Lets go of a token whose process ended. A token whose group still runs a child stays until that child ends.
    func release(_ token: String) {
        lock.withLock {
            guard let group = records[token]?.group, kill(-group, 0) == 0 else {
                if let group = records[token]?.group { groups[group] = nil }
                records[token] = nil
                return
            }
            records[token]?.hasEnded = true
        }
    }

    /// The spot whose token the environment of a call holds, or nil for the person's call.
    public func caller(of environment: [String: String]) -> Caller? {
        guard let token = environment[Self.variable] else { return nil }
        return lock.withLock { records[token]?.caller }
    }

    /// The environment of a call from a process: with the token, the ID and the reason of the spot whose group holds the
    /// process, or as it is for a process of no known group, whose token alone can name its spot. In Careful mode, a process
    /// in a sandbox that neither names is a caller with no use, such as a spot's child that left its group.
    public func environment(of peer: pid_t, over environment: [String: String]) -> [String: String] {
        let group = getpgid(peer)
        guard group > 0 else { return environment }
        let known: (String, Record)? = lock.withLock {
            guard let token = groups[group], let record = records[token] else { return nil }
            guard kill(group, 0) != 0 || Self.start(of: group) == record.start else {
                groups[group] = nil
                return nil
            }
            return (token, record)
        }
        guard let (token, record) = known else {
            guard isCareful, caller(of: environment) == nil, Self.isSandboxed(peer) else { return environment }
            return environment.merging([Self.variable: Self.sandboxed]) { _, new in new }
        }
        var environment = environment
        environment[Self.variable] = token
        environment["OPENSPOT_ID"] = record.caller.id
        environment[Self.reason] = record.reason
        return environment
    }

    /// When a process started, which tells it apart from a later process with the same ID, or 0 when none runs.
    private static func start(of id: pid_t) -> UInt64 {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(id, RUSAGE_INFO_V2, $0) }
        }
        return result == 0 ? info.ri_proc_start_abstime : 0
    }
}
