import Foundation

public struct SpotState: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let on: Bool?
    public let level: Double?
    public let min: Double?
    public let max: Double?
    public let isOnGrid: Bool
    public let values: [String: [String]]
    public let control: String?
    public private(set) var face: CardFace

    public init(
        title: String,
        subtitle: String? = nil,
        on: Bool? = nil,
        level: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        isOnGrid: Bool = true,
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
        self.values = values
        self.control = control
        self.face = face
    }

    public init(output: SpotOutput, header: SpotState) {
        let block = output.summary
        let control = output.control
        var on: Bool?
        if case .toggle(let value)? = control?.control { on = value }
        if let value = block?.flag("active") { on = value }
        var level: (Double, Double, Double)?
        if case .slider(let value, let low, let high)? = output.valuePart?.control { level = (value, low, high) }
        self.init(
            title: block?.value("title") ?? control?.title ?? header.title,
            subtitle: block?.value("detail") ?? control?.detail ?? header.subtitle,
            on: on,
            level: level?.0,
            min: level?.1,
            max: level?.2,
            isOnGrid: header.isOnGrid,
            control: control?.id,
            face: output.face
        )
    }

    public func holding(_ block: TextBlock?) -> SpotState {
        let values = Dictionary(grouping: block?.fields ?? [], by: \.key).mapValues { $0.map(\.value) }
        return SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }

    public func taking(_ output: SpotOutput) -> SpotState {
        var on = self.on
        var level = self.level
        let part = output.parts.first { $0.id == control }
        if case .toggle(let value)? = part?.control { on = value }
        if case .slider(let value, _, _)? = (part ?? output.valuePart)?.control { level = value }
        return SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }

    public func setting(_ value: String, of id: String) -> SpotState {
        var next = self
        next.face.set(value, of: id)
        return next
    }

    public func switched(on: Bool) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }

    public func showing(title: String?, detail: String?) -> SpotState {
        SpotState(title: title ?? self.title, subtitle: detail ?? subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }

    func onGrid(_ isOnGrid: Bool) -> SpotState {
        SpotState(title: title, subtitle: subtitle, on: on, level: level, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }

    public func adjusted(by delta: Double) -> SpotState {
        guard let level else { return self }
        return withLevel(level + delta)
    }

    public func withLevel(_ value: Double) -> SpotState {
        let low = self.min ?? 0
        let high = self.max ?? 100
        let next = Swift.min(Swift.max(value, low), high)
        return SpotState(title: title, subtitle: subtitle, on: on, level: next, min: self.min, max: self.max, isOnGrid: isOnGrid, values: values, control: control, face: face)
    }
}
