import Foundation

/// The last value of a metric. It stays when a later read fails, and is then stale.
public struct MetricReading: Equatable, Sendable {
    public let kind: MetricKind
    public private(set) var value: MetricValue?
    public private(set) var isStale = false

    public init(kind: MetricKind, value: MetricValue? = nil) {
        self.kind = kind
        self.value = value
    }

    public mutating func take(_ value: MetricValue) {
        self.value = value
        isStale = false
    }

    public mutating func markStale() {
        isStale = true
    }
}
