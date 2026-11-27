import Foundation

public final class SpotCallers: @unchecked Sendable {
    private let lock = NSLock()
    private var groups: [pid_t: SpotCaller] = [:]
    private weak var api: CommandAPI?

    private static let sandboxCheck: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32)? =
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sandbox_check").map { unsafeBitCast($0, to: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32).self) }

    static func isSandboxed(_ process: pid_t) -> Bool {
        sandboxCheck?(process, nil, 0) == 1
    }

    static func isSandboxedApart(_ process: pid_t) -> Bool {
        isSandboxed(process) && !isSandboxed(getpid())
    }

    public init() {}

    public func issue(for spot: Spot, reason: String? = nil, keepsFix: Bool = false) -> SpotCaller {
        SpotCaller(spot: spot, reason: reason, keepsFix: keepsFix)
    }

    func serve(by api: CommandAPI) {
        lock.withLock { self.api = api }
    }

    func channel(for caller: SpotCaller) -> RunChannel? {
        lock.withLock { api }.flatMap { caller.channel(serving: $0) }
    }

    func attach(_ process: ScriptProcess, to caller: SpotCaller) {
        process.channel = channel(for: caller)
        caller.process = process
        process.onStart { [self] group in enter(group, caller: caller) }
        process.onExit { [self] _ in release(caller) }
    }

    func enter(_ group: pid_t, caller: SpotCaller) {
        let start = Self.start(of: group)
        lock.withLock {
            for (other, held) in groups where held.hasEnded && kill(-other, 0) != 0 {
                groups[other] = nil
            }
            guard !caller.hasEnded else { return }
            caller.group = (group, start)
            groups[group] = caller
        }
    }

    func release(_ caller: SpotCaller) {
        caller.end()
        lock.withLock {
            guard let group = caller.group?.id, kill(-group, 0) != 0 else { return }
            if groups[group] === caller { groups[group] = nil }
        }
    }

    public func caller(of peer: pid_t) -> SpotCaller? {
        let group = getpgid(peer)
        guard group > 0 else { return nil }
        return lock.withLock {
            guard let caller = groups[group] else { return nil }
            guard kill(group, 0) != 0 || Self.start(of: group) == caller.group?.start else {
                groups[group] = nil
                return nil
            }
            return caller
        }
    }

    private static func start(of id: pid_t) -> UInt64 {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(id, RUSAGE_INFO_V2, $0) }
        }
        return result == 0 ? info.ri_proc_start_abstime : 0
    }
}
