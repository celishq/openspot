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

    /// Reads the block that says how a spot looks, and keeps what the block leaves out from the header.
    public init(block: TextBlock?, header: SpotState) {
        self.init(
            title: block?.value("title") ?? header.title,
            subtitle: block?.value("detail") ?? header.subtitle,
            on: block?.flag("on"),
            level: block?.number("level"),
            min: block?.number("min"),
            max: block?.number("max")
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
