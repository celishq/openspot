import Foundation

/// One piece of live data from a plugin, named by its folder and name, such as battery/level.
public struct PluginMetric: Equatable, Sendable {
    public static let standardRefresh: TimeInterval = 60

    public let id: String
    public let name: String
    public let url: URL
    public let kind: MetricKind
    public let label: String
    public let tint: MetricTint?
    public let refresh: TimeInterval

    public init(id: String, name: String, url: URL, kind: MetricKind, label: String? = nil, tint: MetricTint? = nil, refresh: TimeInterval = PluginMetric.standardRefresh) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.label = label ?? name
        self.tint = tint
        self.refresh = refresh
    }

    public func read(timeout: TimeInterval) async throws -> MetricValue {
        let output = try await PluginRun(url: url, arguments: SpotAction.metric(name).arguments, timeout: timeout).output()
        guard let value = TextBlock.blocks(in: output).first.flatMap(MetricValue.init(block:)) else {
            throw PluginError.badMetric
        }
        return value
    }
}
