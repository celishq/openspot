import Foundation

public struct SpotState: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let on: Bool?
    public let level: Double?
    public let min: Double?
    public let max: Double?

    public init(
        title: String,
        subtitle: String? = nil,
        on: Bool? = nil,
        level: Double? = nil,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.on = on
        self.level = level
        self.min = min
        self.max = max
    }

    /// Reads the block a state prints. Only the title is required.
    public init?(block: TextBlock) {
        guard let title = block.value("title") else { return nil }
        self.init(
            title: title,
            subtitle: block.value("subtitle"),
            on: block.flag("on"),
            level: block.number("level"),
            min: block.number("min"),
            max: block.number("max")
        )
    }

    public func adjusted(by delta: Double) -> SpotState {
        guard let level else { return self }
        return withLevel(level + delta)
    }

    public func withLevel(_ value: Double) -> SpotState {
        let low = self.min ?? 0
        let high = self.max ?? 100
        let next = Swift.min(Swift.max(value, low), high)
        return SpotState(title: title, subtitle: subtitle, on: on, level: next, min: self.min, max: self.max)
    }
}
