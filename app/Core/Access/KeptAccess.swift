import Foundation

final class KeptAccess: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [MacAccess: ReadAccess] = [:]

    var statuses: [MacAccess: ReadAccess] {
        lock.withLock { kept }
    }

    func read(_ wanted: Set<MacAccess>, from mac: Mac, apps: [ReadAccess] = []) async -> [MacAccess: ReadAccess] {
        var read: [MacAccess: ReadAccess] = [:]
        for access in MacAccess.allCases where wanted.contains(access) {
            read[access] = switch access {
            case .automation: Self.joined(apps)
            case .accessibility: mac.reads?.accessibility(asks: false) ?? .unknown
            default: await mac.accesses?.status(of: access) ?? .unknown
            }
        }
        let found = read
        lock.withLock { kept.merge(found) { $1 } }
        return read
    }

    private static func joined(_ apps: [ReadAccess]) -> ReadAccess {
        [.denied, .unasked, .allowed].first(where: apps.contains) ?? .unknown
    }
}
