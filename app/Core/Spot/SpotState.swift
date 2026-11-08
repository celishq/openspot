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
    /// The id of the switch or the slider that its card changes, which a change of the card sends (U12).
    public let control: String?
    /// The drawings of its card, with the components that they place (U5).
    public private(set) var face: CardFace

    public init(
        title: String,
        subtitle: String? = nil,
        on: Bool? = nil,
        level: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        isOnGrid: Bool = true,
        size: SpotSize? = nil,
        values: [String: [String]] = [:],
        control: String? = nil,
        face: CardFace = .none
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
        self.control = control
        self.face = face
    }

    /// Reads how a spot looks from what its script printed: the words of its head, and the first switch, which says whether
    /// its card is on, and the first slider. A spot
    /// whose output is one switch or one slider takes that control's words for its card (U12). What the output leaves out
    /// comes from the header.
    public init(output: PluginOutput, header: SpotState) {
        let block = output.summary
        let toggle = output.parts.first { $0.kind == "switch" }
        let slider = output.parts.first { $0.kind == "slider" }
        let control = output.control
        var on: Bool?
        if case .toggle(let value)? = toggle?.control { on = value }
        var level: (Double, Double, Double)?
        if case .slider(let value, let low, let high)? = slider?.control { level = (value, low, high) }
        self.init(
            title: block?.value("title") ?? control?.title ?? header.title,
            subtitle: block?.value("detail") ?? control?.detail ?? header.subtitle,
            on: on,
            level: level?.0,
            min: level?.1,
            max: level?.2,
            isOnGrid: header.isOnGrid,
            size: block?.value("size").flatMap(SpotSize.init(name:)) ?? header.size,
            control: control?.id,
            face: output.face
        )
    }

    /// This state with each value of a block, which a view draws.
    public func holding(_ block: TextBlock?) -> SpotState {
        let values = Dictionary(grouping: block?.fields ?? [], by: \.key).mapValues { $0.map(\.value) }
        return SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }

    /// This state with what a frame of a running call changes: the value of its card's control, or of its first switch.
    /// Its words stay the spot's own.
    public func taking(_ output: PluginOutput) -> SpotState {
        var on = self.on
        var level = self.level
        let part = output.parts.first { $0.id == control } ?? output.parts.first { $0.kind == "switch" }
        if case .toggle(let value)? = part?.control { on = value }
        if case .slider(let value, _, _)? = part?.control { level = value }
        return SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }

    /// This state with a value that the person set on a component of its card, before the script answers.
    public func setting(_ value: String, of id: String) -> SpotState {
        var next = self
        next.face.set(value, of: id)
        return next
    }

    /// This state with its switch set, as a press of its card sets it before the script answers.
    public func switched(on: Bool) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }

    /// This state with the words of a running call over its own. A word the call leaves out stays.
    public func showing(title: String?, detail: String?) -> SpotState {
        SpotState(title: title ?? self.title, subtitle: detail ?? subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }

    /// This state, on the grid or off it.
    func onGrid(_ isOnGrid: Bool) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }

    public func adjusted(by delta: Double) -> SpotState {
        guard let level else { return self }
        return withLevel(level + delta)
    }

    public func withLevel(_ value: Double) -> SpotState {
        let low = self.min ?? 0
        let high = self.max ?? 100
        let next = Swift.min(Swift.max(value, low), high)
        return SpotState(title: title, subtitle: subtitle, on: on, level: next, min: self.min, max: self.max, isOnGrid: isOnGrid, size: size, values: values, control: control, face: face)
    }
}
