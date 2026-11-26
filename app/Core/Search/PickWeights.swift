import Foundation

struct PickWeights: Equatable, Sendable {
    private var values: [String: Double] = [:]

    init(_ picks: [String] = []) {
        SearchRanks.meter?.addWeights()
        var weight = 1.0
        for run in picks {
            values[run, default: 0] += weight
            weight *= 0.9
        }
    }

    func weight(of run: String) -> Double {
        values[run] ?? 0
    }
}
