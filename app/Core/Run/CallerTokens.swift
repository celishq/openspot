import Foundation

/// The token of each process and inline link of a spot that runs, which marks its calls of `openspot` as the spot's (Z2).
/// A call with no token, or with one that is not here, is the person's.
public final class CallerTokens: @unchecked Sendable {
    /// The spot that a token stands for.
    public struct Caller: Equatable, Sendable {
        public let id: String
        public let name: String
        public let uses: Set<SpotUse>
    }

    public static let variable = "OPENSPOT_TOKEN"

    private let lock = NSLock()
    private var callers: [String: Caller] = [:]

    public init() {}

    /// A new random token that stands for the spot until its release.
    func issue(for spot: Spot) -> String {
        var random = SystemRandomNumberGenerator()
        let token = String(format: "%016llx%016llx", random.next() as UInt64, random.next() as UInt64)
        lock.withLock { callers[token] = Caller(id: spot.id, name: spot.name, uses: spot.uses) }
        return token
    }

    func release(_ token: String) {
        lock.withLock { callers[token] = nil }
    }

    /// The spot whose token the environment of a call holds, or nil for the person's call.
    public func caller(of environment: [String: String]) -> Caller? {
        guard let token = environment[Self.variable] else { return nil }
        return lock.withLock { callers[token] }
    }
}
