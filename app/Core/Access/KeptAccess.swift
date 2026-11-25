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
        return (await read(MacAccess.allCases, from: mac, apps: apps), apps)
    }

    func read(_ accesses: [MacAccess], from mac: Mac, browsers: [Browser]) async -> [MacAccess: ReadAccess] {
        var apps: [TextBlock] = []
        if accesses.contains(.automation), let reads = mac.reads { apps = await ReadSources(mac: reads).access(browsers: browsers) }
        return await read(accesses, from: mac, apps: apps)
    }

    private func read(_ accesses: [MacAccess], from mac: Mac, apps: [TextBlock]) async -> [MacAccess: ReadAccess] {
        let automation = apps.filter { $0.value("app") != ReadSources.accessibility }.compactMap { $0.value("access").flatMap(ReadAccess.init) }
        var read: [MacAccess: ReadAccess] = [:]
        for access in accesses {
            read[access] = switch access {
            case .automation: Self.joined(automation)
            case .accessibility: mac.reads?.accessibility(asks: false) ?? .unknown
            default: await mac.accesses?.status(of: access) ?? .unknown
            }
        }
        let found = read
        lock.withLock { kept.merge(found) { _, new in new } }
        return read
    }

    private static func joined(_ apps: [ReadAccess]) -> ReadAccess {
        [.denied, .unasked, .allowed].first(where: apps.contains) ?? .unknown
    }
}
