import Foundation

final class KeptAccess: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [MacAccess: ReadAccess] = [:]

    var statuses: [MacAccess: ReadAccess] {
        lock.withLock { kept }
    }

    func read(from mac: Mac, browsers: [Browser]) async -> (statuses: [MacAccess: ReadAccess], apps: [TextBlock]) {
        var apps: [TextBlock] = []
        if let reads = mac.reads { apps = await ReadSources(mac: reads).access(browsers: browsers) }
        let automation = apps.filter { $0.value("app") != ReadSources.accessibility }.compactMap { $0.value("access").flatMap(ReadAccess.init) }
        var read: [MacAccess: ReadAccess] = [:]
        for access in MacAccess.allCases {
            read[access] = switch access {
            case .automation: Self.joined(automation)
            case .accessibility: mac.reads?.accessibility(asks: false) ?? .unknown
            default: await mac.accesses?.status(of: access) ?? .unknown
            }
        }
        let found = read
        lock.withLock { kept = found }
        return (read, apps)
    }

    private static func joined(_ apps: [ReadAccess]) -> ReadAccess {
        [.denied, .unasked, .allowed].first(where: apps.contains) ?? .unknown
    }
}
