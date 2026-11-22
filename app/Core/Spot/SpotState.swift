import Foundation

public struct SpotState: Equatable, Sendable {
    public private(set) var title: String
    public private(set) var subtitle: String?
    public private(set) var on: Bool?
    public private(set) var level: Double?
    public let min: Double?
    public let max: Double?
    public private(set) var isOnGrid: Bool
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
        self.control = control
        self.face = face
    }

    public init(output: Frame, header: SpotState) {
        let block = output.root
        let control = output.control
        var on: Bool?
        if case .toggle(let value)? = control?.control { on = value }
        if let value = block?.flag("active") { on = value }
        var level: (Double, Double, Double)?
        if case .slider(let value, let low, let high)? = output.valuePart?.control { level = (value, low, high) }
        self.init(
            title: block?.value("title") ?? header.title,
            subtitle: block?.value("detail") ?? header.subtitle,
            on: on,
            level: level?.0,
            min: level?.1,
            max: level?.2,
            isOnGrid: header.isOnGrid,
            control: control?.id,
            face: output.face
        )
    }

    public func taking(_ output: Frame) -> SpotState {
        var next = self
        let part = output.parts.first { $0.id == control }
        if case .toggle(let value)? = part?.control { next.on = value }
        if case .slider(let value, _, _)? = (part ?? output.valuePart)?.control { next.level = value }
        return next
    }

    public func setting(_ value: String, of id: String) -> SpotState {
        var next = self
        next.face.set(value, of: id)
        return next
    }

    public func switched(on: Bool) -> SpotState {
        var next = self
        next.on = on
        return next
    }

    public func showing(title: String?, detail: String?) -> SpotState {
        var next = self
        next.title = title ?? self.title
        next.subtitle = detail ?? subtitle
        return next
    }

    func onGrid(_ isOnGrid: Bool) -> SpotState {
        var next = self
        next.isOnGrid = isOnGrid
        return next
    }

    public func withLevel(_ value: Double) -> SpotState {
        var next = self
        next.level = Swift.min(Swift.max(value, self.min ?? 0), self.max ?? 100)
        return next
    }
}
