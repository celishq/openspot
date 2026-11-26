import Foundation

extension Stats {
    public var refused: [String: [SpotUse: Date]] {
        var refused: [String: [SpotUse: Date]] = [:]
        for kept in uses {
            guard let use = kept.use else { continue }
            refused[kept.spot, default: [:]][use] = max(refused[kept.spot]?[use] ?? .distantPast, kept.time)
        }
        return refused
    }
}
