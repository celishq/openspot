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
        case number(String, unit: String?)
        case chart([Double])
        case image(String)
        case progress(level: Double)
        case shortcut(String)
    }

    public enum Press: Equatable, Sendable {
        case none
        case line
        case symbol(String)
    }

    public enum Look: String, Equatable, Sendable {
        case tile, chip, strong, bare, tick
    }

    public enum Align: String, Equatable, Sendable {
        case left, center, right
    }

    public let id: String
    public let kind: String
    public let isSection: Bool
    public let title: String?
    public let detail: String?
    public let symbol: String?
    public let file: String?
    public let glyph: String?
    public let tone: MetricValue.Tone?
    public let color: String?
    public private(set) var control: Control
    public let press: Press
    public let key: ActionKey?
    public let closes: Bool
    public let align: Align?
    public let look: Look?
    public let mark: MetricValue?
    public let values: [String: [String]]

    public struct NumberPiece: Equatable, Sendable {
        public let text: String
        public let isUnit: Bool
    }

    public static let kinds = ["text", "number", "gauge", "graph", "picture", "view", "switch", "slider", "field", "choice", "hotkey", "button", "section"]

    public init?(block: TextBlock) {
        guard let kind = block.fields.first?.key, Self.kinds.contains(kind), let id = block.value(kind) else { return nil }
        self.id = id
        self.kind = kind
        values = kind == "view" ? Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) } : [:]
        isSection = kind == "section"
        title = block.value("title")
        detail = block.value("detail")
        key = kind == "hotkey" ? nil : block.value("shortcut").flatMap(ActionKey.init(text:))
        closes = block.flag("close") ?? false
        align = block.value("align").flatMap(Align.init(rawValue:))
        look = block.value("look").flatMap(Look.init(rawValue:))
        let icon = Icon(text: block.value("icon"))
        let symbol = icon?.symbol
        file = icon?.file
        glyph = icon?.glyph
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
        color = ["text", "number"].contains(kind) ? block.value("color").flatMap(Self.hex) : nil
        if kind == "button" {
            self.symbol = nil
            press = symbol.map(Press.symbol) ?? .line
        } else {
            self.symbol = symbol
            press = .none
        }
        switch kind {
        case "switch":
            control = .toggle(block.flag("value") ?? false)
        case "gauge":
            control = .progress(level: (block.number("value") ?? 0) * 100)
        case "graph":
            control = .chart(block.values("value").compactMap(Double.init))
        case "picture":
            control = icon?.image.map(Control.image) ?? .none
        case "slider":
            control = .slider(level: block.number("value") ?? 0, min: block.number("min") ?? 0, max: block.number("max") ?? 100)
        case "field":
            control = .text(block.value("value") ?? "", placeholder: block.value("placeholder"), isReadOnly: block.flag("readonly") ?? false)
        case "hotkey":
            control = .shortcut(block.value("value") ?? "")
        case "choice":
            let options = Self.options(of: block)
            if !block.values("color").isEmpty {
                control = .swatches(block.values("color"), value: block.value("value"))
            } else {
                control = .menu(options, value: block.value("value"))
            }
        case "number":
            control = .number(block.value("display") ?? block.value("value") ?? "", unit: block.value("unit").flatMap { $0.isEmpty ? nil : $0 })
        default:
            control = .none
        }
        mark = control == .none && kind == "text" ? Self.mark(block) : nil
    }

    private static func hex(_ text: String) -> String? {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit) ? text : nil
    }

    private static func mark(_ block: TextBlock) -> MetricValue? {
        let data = MetricValue.data(of: block)
        guard data.value != nil || data.points != nil else { return nil }
        return MetricValue(
            title: block.value("detail") ?? "",
            tone: block.value("tone").flatMap(MetricValue.Tone.init),
            value: data.value,
            points: data.points,
            max: block.number("max")
        )
    }

    public var numberPieces: [NumberPiece] {
        guard case .number(let number, let unit) = control else { return [] }
        guard let unit, let range = number.range(of: unit, options: .backwards) else { return [NumberPiece(text: number, isUnit: false)] }
        return [
            NumberPiece(text: String(number[..<range.lowerBound]), isUnit: false),
            NumberPiece(text: unit, isUnit: true),
            NumberPiece(text: String(number[range.upperBound...]), isUnit: false),
        ].filter { !$0.text.isEmpty }
    }

    public var textTone: MetricValue.Tone? {
        kind == "text" ? tone : nil
    }

    static func options(of block: TextBlock) -> [Option] {
        block.children.compactMap { child in
            child.value("option").map { Option(id: $0, title: child.value("title") ?? $0, icon: child.value("icon")) }
        }
    }

    public var value: String? {
        switch control {
        case .none, .number, .chart, .image, .progress: nil
        case .toggle(let on): on ? "true" : "false"
        case .slider(let level, _, _): String(Int(level.rounded()))
        case .swatches(_, let value), .menu(_, let value), .list(_, let value): value
        case .text(let text, _, _): text
        case .shortcut(let text): text
        }
    }

    public func drawn(in layout: SheetLayout?) -> SpotPart {
        guard case .menu(let options, let value) = control, let area = layout?.areas[id], area.y1 > area.y0 else { return self }
        var part = self
        part.control = .list(options, value: value)
        return part
    }

    public var ringWords: String? {
        guard mark?.kind == .gauge, let detail else { return nil }
        return detail.hasSuffix("%") ? String(detail.dropLast()) : detail
    }

    public var fillsHeight: Bool {
        if kind == "view" { return true }
        return switch control {
        case .text, .list, .number, .chart, .image, .progress: true
        default: false
        }
    }

    public var fillsWidth: Bool {
        if look == .chip || look == .bare { return title != nil && control != .none }
        if case .symbol = press, title == nil, control == .none { return false }
        return true
    }

    public var scrollsItself: Bool {
        switch control {
        case .text, .list: true
        default: false
        }
    }

    var growsRow: Bool {
        if kind == "view" { return true }
        return switch control {
        case .text, .list, .chart, .image: true
        default: false
        }
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
        case .none, .number, .chart, .image, .progress: break
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
