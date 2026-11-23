import Foundation

public enum MetricKind: String, CaseIterable, Sendable {
    case value
    case gauge
    case trend
    case rows
    case status
}
