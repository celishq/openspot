import Foundation

final class KeptCalls: @unchecked Sendable {
    static let shared = KeptCalls()

    private let limit = 1024
    private let lock = NSLock()
    private var kept: [String: (stamp: [Double], calls: [[String]])] = [:]

    func read(_ spot: Spot) -> [[String]] {
        let folder = spot.url.deletingLastPathComponent()
        let sources = SwiftProgram.paths(named: spot.sources, beside: spot.url).map { folder.appendingPathComponent($0).path }
        return ([spot.url.path] + spot.views.values.sorted() + sources).flatMap(read)
    }

    private func read(_ path: String) -> [[String]] {
        let info = try? FileManager.default.attributesOfItem(atPath: path)
        let stamp = [(info?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0, Double((info?[.size] as? Int) ?? -1)]
        if let found = lock.withLock({ kept[path] }), found.stamp == stamp { return found.calls }
        let calls = (try? String(contentsOfFile: path, encoding: .utf8)).map(WrittenCalls.calls) ?? []
        lock.withLock {
            if kept.count >= limit { kept.removeAll() }
            kept[path] = (stamp, calls)
        }
        return calls
    }
}
