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
    /// The size of its card that a read asks for. Nil keeps the header's.
    public let size: SpotSize?
    /// Each value of the head of its last read by key, in order, which its view draws (V4).
    public let values: [String: [String]]

    public init(
        title: String,
        subtitle: String? = nil,
        on: Bool? = nil,
        level: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        isOnGrid: Bool = true,
        size: SpotSize? = nil,
        values: [String: [String]] = [:]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.on = on
        self.level = level
        self.min = min
        self.max = max
        self.isOnGrid = isOnGrid
        self.size = size
        self.values = values
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
            isOnGrid: header.isOnGrid,
            size: block?.value("size").flatMap(SpotSize.init(name:)) ?? header.size
        )
    }

    /// This state with each value of a block, which a view draws.
    public func holding(_ block: TextBlock?) -> SpotState {
        let values = Dictionary(grouping: block?.fields ?? [], by: \.key).mapValues { $0.map(\.value) }
        return SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values)
    }

    /// This state with what a frame of a running call changes: only its `on` and its `level`. Its words stay the spot's own.
    public func taking(_ block: TextBlock) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: block.flag("on") ?? on, level: block.number("level") ?? level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values)
    }

    /// This state with the words of a running call over its own. A word the call leaves out stays.
    public func showing(title: String?, detail: String?) -> SpotState {
        SpotState(title: title ?? self.title, subtitle: detail ?? subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values)
    }

    /// This state, on the grid or off it.
    func onGrid(_ isOnGrid: Bool) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values)
    }

    public func adjusted(by delta: Double) -> SpotState {
        guard let level else { return self }
        return withLevel(level + delta)
    }

    public func withLevel(_ value: Double) -> SpotState {
        let low = self.min ?? 0
        let high = self.max ?? 100
        let next = Swift.min(Swift.max(value, low), high)
        return SpotState(title: title, subtitle: subtitle, on: on, level: next, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values)
    }
}
