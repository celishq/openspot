import Foundation

/// One piece of live data: a script with a number of seconds as its `read`, named by its path, such as battery.
public struct PluginMetric: Equatable, Sendable {
    public let id: String
    public let url: URL
    public let label: String
    public let symbol: String?
    public let refresh: TimeInterval
    public let isTray: Bool

    public init(id: String, url: URL, label: String? = nil, symbol: String? = nil, refresh: TimeInterval = 60, isTray: Bool = false) {
        self.id = id
        self.url = url
        self.label = label ?? id
        self.symbol = symbol
        self.refresh = refresh
        self.isTray = isTray
    }

    public func read(timeout: TimeInterval) async throws -> MetricValue {
        let output = try await PluginRun(url: url, arguments: SpotAction.read.arguments, timeout: timeout).output()
        guard let value = MetricValue(output: PluginOutput(text: output)) else { throw PluginError.badMetric }
        return value
    }
}
