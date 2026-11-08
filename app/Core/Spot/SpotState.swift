import Foundation

public struct SpotState: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let on: Bool?
    public let level: Double?
    public let min: Double?
    public let max: Double?
    /// Whether the grid shows the spot. Search and its key find it either way.
    public let isOnGrid: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        on: Bool? = nil,
        level: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        isOnGrid: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.on = on
        self.level = level
        self.min = min
        self.max = max
        self.isOnGrid = isOnGrid
    }

    /// Reads the block that says how a spot looks, and keeps what the block leaves out from the header.
    public init(block: TextBlock?, header: SpotState) {
        self.init(
            title: block?.value("title") ?? header.title,
            subtitle: block?.value("detail") ?? header.subtitle,
            on: block?.flag("on"),
            level: block?.number("level"),
            min: block?.number("min"),
            max: block?.number("max"),
            isOnGrid: block?.flag("grid") ?? header.isOnGrid
        )
    }

    /// This state with what a frame of a running call changes: only its `on` and its `level`. Its words stay the spot's own.
    public func taking(_ block: TextBlock) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: block.flag("on") ?? on, level: block.number("level") ?? level, min: self.min, max: self.max, isOnGrid: isOnGrid)
    }

    /// This state with the words of a running call over its own. A word the call leaves out stays.
    public func showing(title: String?, detail: String?) -> SpotState {
        SpotState(title: title ?? self.title, subtitle: detail ?? subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid)
    }

    public func adjusted(by delta: Double) -> SpotState {
        guard let level else { return self }
        return withLevel(level + delta)
    }

    public func withLevel(_ value: Double) -> SpotState {
        let low = self.min ?? 0
        let high = self.max ?? 100
        let next = Swift.min(Swift.max(value, low), high)
        return SpotState(title: title, subtitle: subtitle, on: on, level: next, min: self.min, max: self.max, isOnGrid: isOnGrid)
    }
}
