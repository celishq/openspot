import Foundation

public struct MetricReading: Equatable, Sendable {
    public private(set) var kind: MetricKind
    public let label: String
    public let headerSymbol: String?
    public private(set) var value: MetricValue?
    public private(set) var isStale = false

    public init(label: String, headerSymbol: String? = nil, value: MetricValue? = nil) {
        kind = value?.kind ?? .value
        self.label = label
        self.headerSymbol = headerSymbol
        self.value = value
    }

    public var symbol: String? {
        value?.symbol ?? headerSymbol
    }

    public mutating func take(_ value: MetricValue) {
        isStale = false
        if value.isHidden {
            self.value = kind == .rows ? MetricValue(title: "0", isHidden: true) : value
        } else {
            kind = value.kind
            self.value = value
        }
    }

    public mutating func markStale() {
        isStale = true
    }
}
