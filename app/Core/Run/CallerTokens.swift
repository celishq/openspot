import Foundation

public final class CallerTokens: @unchecked Sendable {
    public struct Caller: Equatable, Sendable {
        public let id: String
        public let name: String
        public let uses: Set<SpotUse>
        public var isBuiltIn = false
        public var isRestricted = false
        public var dataName: String?

        public var reachesAccountKey: Bool {
            SpotUse.reachesAccountKey(uses, isBuiltIn: isBuiltIn)
        }
    }

    private struct Record {
        let caller: Caller
        var reason: String?
        var group: pid_t?
        var start: UInt64 = 0
        var hasEnded = false
        var keepsFix = false
        var fix: URL?
    }

    public static let variable = "OPENSPOT_TOKEN"
    private static let reason = ReadReason.variable
    private static let fixLimit = 64

    private let lock = NSLock()
    private var records: [String: Record] = [:]
    private var groups: [pid_t: String] = [:]
    private var fixes: [String: URL] = [:]
    private var careful = false
    private var kept = SpotTrust()

    private static let sandboxed = "sandboxed"
    private static let sandboxCheck: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32)? =
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sandbox_check").map { unsafeBitCast($0, to: (@convention(c) (pid_t, UnsafePointer<CChar>?, Int32) -> Int32).self) }

    static func isSandboxed(_ process: pid_t) -> Bool {
        sandboxCheck?(process, nil, 0) == 1
    }

    static func isSandboxedApart(_ process: pid_t) -> Bool {
        isSandboxed(process) && !isSandboxed(getpid())
    }

    public init() {
        records[Self.sandboxed] = Record(caller: Caller(id: "", name: "A sandboxed process", uses: [], isRestricted: true))
    }

    func issue(for spot: Spot, reason: String? = nil, keepsFix: Bool = false) -> String {
        var random = SystemRandomNumberGenerator()
        let token = String(format: "%016llx%016llx", random.next() as UInt64, random.next() as UInt64)
        lock.withLock { records[token] = Record(caller: Caller(id: spot.id, name: spot.name, uses: spot.uses, isBuiltIn: spot.isBuiltIn, isRestricted: spot.isRestricted, dataName: spot.dataName), reason: reason, keepsFix: keepsFix) }
        return token
    }

    public var isCareful: Bool {
        get { lock.withLock { careful } }
        set { lock.withLock { careful = newValue } }
    }

    public var trust: SpotTrust {
        get { lock.withLock { kept } }
        set { lock.withLock { kept = newValue } }
    }

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

    func setReason(_ reason: String?, of token: String) {
        lock.withLock { records[token]?.reason = reason }
    }

    func release(_ token: String) {
        lock.withLock {
            if let fix = records[token]?.fix {
                if fixes.count >= Self.fixLimit { fixes = [:] }
                fixes[token] = fix
            }
            guard let group = records[token]?.group, kill(-group, 0) == 0 else {
                if let group = records[token]?.group { groups[group] = nil }
                records[token] = nil
                return
            }
            records[token]?.hasEnded = true
        }
    }

    func note(_ fix: URL?, of token: String) {
        lock.withLock {
            guard records[token]?.hasEnded == false, records[token]?.keepsFix == true else { return }
            records[token]?.fix = fix
        }
    }

    func fix(of token: String) -> URL? {
        lock.withLock {
            defer { fixes[token] = nil }
            return fixes[token] ?? records[token]?.fix
        }
    }

    public func caller(of token: String?) -> Caller? {
        guard let token else { return nil }
        return lock.withLock { records[token]?.caller }
    }

    func variables(of token: String?) -> [String: String] {
        guard let token, let record = lock.withLock({ records[token] }), !record.caller.id.isEmpty else { return [:] }
        var variables = ["OPENSPOT_ID": record.caller.id]
        variables[Self.reason] = record.reason
        return variables
    }

    public func token(of peer: pid_t, claimed: String?) -> (token: String?, isBound: Bool) {
        let group = getpgid(peer)
        guard group > 0 else { return (claimed, false) }
        let known: String? = lock.withLock {
            guard let token = groups[group], let record = records[token] else { return nil }
            guard kill(group, 0) != 0 || Self.start(of: group) == record.start else {
                groups[group] = nil
                return nil
            }
            return token
        }
        if let known { return (known, true) }
        guard caller(of: claimed) == nil, Self.isSandboxed(peer) else { return (claimed, false) }
        return (Self.sandboxed, false)
    }

    private static func start(of id: pid_t) -> UInt64 {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(id, RUSAGE_INFO_V2, $0) }
        }
        return result == 0 ? info.ri_proc_start_abstime : 0
    }
}
