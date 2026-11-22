import Foundation

public struct SpotPart: Equatable, Sendable, Identifiable {
    public struct Option: Equatable, Sendable {
        public let id: String
        public let title: String
        public let icon: String?

        public init(id: String, title: String, icon: String? = nil) {
            self.id = id
            self.title = title
            self.icon = icon
        }
    }

    public enum Control: Equatable, Sendable {
        case none
        case toggle(Bool)
        case slider(level: Double, min: Double, max: Double)
        case swatches([String], value: String?)
        case menu([Option], value: String?)
        case text(String, placeholder: String?, isReadOnly: Bool)
        case list([Option], value: String?)
        case number(NumberReading)
        case image(String)
        case shortcut(String)
    }

    public enum Press: Equatable, Sendable {
        case none
        case line
        case round(Icon)
    }

    public enum Look: Equatable, Sendable {
        case tile, chip, strong, bare

        public init?(style: Style) {
            switch style.fill {
            case .accent: self = .strong
            case .tile: self = .tile
            case .transparent: self = .bare
            default:
                guard style.corner == .full else { return nil }
                self = .chip
            }
        }
    }

    public let id: String
    public let kind: String
    public let title: String?
    public let detail: String?
    public let icon: Icon?
    public let tone: MetricValue.Tone?
    public let color: String?
    public private(set) var control: Control
    public let press: Press
    public let key: ActionKey?
    public let asksToRecord: Bool
    public let closes: Bool
    public private(set) var look: Look?
    public let isTick: Bool
    public let isMultiline: Bool

    public struct NumberPiece: Equatable, Sendable {
        public let text: String
        public let isUnit: Bool
    }

    public init?(block: TextBlock, kinds: [BlockKind] = BlockKind.all) {
        guard let kind = BlockKind.of(block, in: kinds) else { return nil }
        self.init(block: block, kind: kind)
    }

    init?(block: TextBlock, kind: BlockKind) {
        guard let id = block.value(kind.word) else { return nil }
        self.id = id
        self.kind = kind.name
        title = block.value("title")
        detail = block.value("detail")
        key = kind == .hotkey ? nil : block.value("shortcut").flatMap(ActionKey.init(text:))
        asksToRecord = kind == .hotkey && block.flag("recording") == true
        closes = block.flag("close") ?? kind.presses
        let style = StyleCache.shared.style(of: block.value(ViewNode.classKey) ?? "").resolved(for: [.sheet])
        look = Look(style: style)
        isTick = kind.takesTick && block.value("type") == "tick"
        isMultiline = kind == .field && block.value("type") == ViewNode.multiline
        let icon = Icon(text: block.value("icon"))
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
        color = kind.takesColor ? block.value("color").flatMap { BlockKind.isColor($0) ? $0 : nil } : nil
        let round = kind.presses && title == nil && style.corner == .full ? icon : nil
        self.icon = round == nil ? icon : nil
        press = kind.presses ? round.map(Press.round) ?? .line : .none
        control = kind.control(block)
    }

    public var numberPieces: [NumberPiece] {
        guard let reading = number else { return [] }
        let number = reading.text
        let unit = reading.unit
        guard let unit, let range = number.range(of: unit, options: .backwards) else { return [NumberPiece(text: number, isUnit: false)] }
        return [
            NumberPiece(text: String(number[..<range.lowerBound]), isUnit: false),
            NumberPiece(text: unit, isUnit: true),
            NumberPiece(text: String(number[range.upperBound...]), isUnit: false),
        ].filter { !$0.text.isEmpty }
    }

    public var number: NumberReading? {
        guard case .number(let reading) = control else { return nil }
        return reading
    }

    static func options(of block: TextBlock) -> [Option] {
        block.children.compactMap { child in
            child.value("option").map { Option(id: $0, title: child.value("title") ?? $0, icon: child.value("icon")) }
        }
    }

    public var value: String? {
        switch control {
        case .none, .number, .image: nil
        case .toggle(let on): on ? "true" : "false"
        case .slider(let level, _, _): String(Int(level.rounded()))
        case .swatches(_, let value), .menu(_, let value), .list(_, let value): value
        case .text(let text, _, _): text
        case .shortcut(let text): text
        }
    }

    public var closesOnSet: Bool {
        switch control {
        case .text, .slider: false
        default: closes
        }
    }

    public func drawn(as look: Look?) -> SpotPart {
        var part = self
        part.look = look
        return part
    }

    public var fillsHeight: Bool {
        switch control {
        case .text: isMultiline
        case .list, .number, .image: true
        default: false
        }
    }

    public var fillsWidth: Bool {
        if look == .chip || look == .bare { return title != nil && control != .none }
        if case .round = press { return false }
        return true
    }

    public var isPressable: Bool {
        press != .none
    }

    public var isEditable: Bool {
        if case .text(_, _, false) = control { return true }
        return false
    }

    public var isFocusable: Bool {
        switch control {
        case .toggle, .shortcut, .menu, .slider: true
        case .text(_, _, let isReadOnly): !isReadOnly
        default: press != .none
        }
    }

    public mutating func set(_ value: String) {
        switch control {
        case .none, .number, .image: break
        case .list(let items, _): control = .list(items, value: value)
        case .toggle: control = .toggle(value == "true")
        case .slider(_, let low, let high): control = .slider(level: Double(value) ?? low, min: low, max: high)
        case .swatches(let colors, _): control = .swatches(colors, value: value)
        case .menu(let options, _): control = .menu(options, value: value)
        case .shortcut: control = .shortcut(value)
        case .text(_, let placeholder, let isReadOnly):
            control = .text(value, placeholder: placeholder, isReadOnly: isReadOnly)
        }
    }
}
