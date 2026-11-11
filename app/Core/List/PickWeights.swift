import Foundation

/// The weight of each picked run, from the latest pick first: each pick weighs 0.9 of the one after it.
struct PickWeights: Equatable, Sendable {
    /// The number of weights made from picks, in all lists. Only a test reads it.
    nonisolated(unsafe) static var builds = 0
    private var values: [String: Double] = [:]

    init(_ picks: [String] = []) {
        Self.builds += 1
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
