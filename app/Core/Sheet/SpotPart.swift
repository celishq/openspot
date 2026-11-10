import Foundation

/// One line of a sheet that a script prints. What the block holds decides what it shows.
public struct SpotPart: Equatable, Sendable, Identifiable {
    public struct Option: Equatable, Sendable {
        public let id: String
        public let title: String
        /// The picture of its row in a form whose one choice shows as rows.
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
        case metric(String)
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

    /// The box that the app draws around it, from the one set that the app owns. `pad` is the look of a key of a keypad, and
    /// `tick` draws a switch as a round tick, for a thing to do.
    public enum Look: String, Equatable, Sendable {
        case tile, chip, strong, bare, pad, tick
    }

    public enum Align: String, Equatable, Sendable {
        case left, center, right
    }

    public let id: String
    /// The kind that its first key names, such as `switch`.
    public let kind: String
    public let isSection: Bool
    public let title: String?
    public let detail: String?
    public let symbol: String?
    /// The file whose icon it shows, and the short text, such as an emoji, that it shows as its picture.
    public let file: String?
    public let glyph: String?
    /// Its colour that means something, or `on` for a dot that says that a thing is active.
    public let tone: MetricValue.Tone?
    /// The colour, as `#RRGGBB`, of the bar that a text or a number draws at its leading edge, such as a calendar's.
    public let color: String?
    public private(set) var control: Control
    public let press: Press
    public let key: ActionKey?
    public let closes: Bool
    public let align: Align?
    public let look: Look?
    /// The small mark of a line, drawn as a widget draws it: a ring around its detail from `value`, or bars before its
    /// detail from `point` lines.
    public let mark: MetricValue?

    /// The kinds of block that make a part, in the order of the table in spec 02 (U2).
    public static let kinds = ["text", "number", "gauge", "graph", "picture", "view", "spot", "switch", "slider", "field", "choice", "hotkey", "button", "section"]

    /// Reads a block whose first key is a kind of part. Its value is the id, and the kind decides the control.
    public init?(block: TextBlock) {
        guard let kind = block.fields.first?.key, Self.kinds.contains(kind), let id = block.value(kind) else { return nil }
        self.id = id
        self.kind = kind
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
            control = .toggle(block.flag("on") ?? false)
        case "gauge":
            control = .progress(level: (block.number("value") ?? 0) * 100)
        case "graph":
            control = .chart(block.values("point").compactMap(Double.init))
        case "picture":
            control = icon?.image.map(Control.image) ?? .none
        case "slider":
            control = .slider(level: block.number("level") ?? 0, min: block.number("min") ?? 0, max: block.number("max") ?? 100)
        case "field":
            control = .text(block.value("text") ?? "", placeholder: block.value("placeholder"), isReadOnly: block.flag("readonly") ?? false)
        case "hotkey":
            control = .shortcut(block.value("value") ?? "")
        case "choice":
            let options = block.values("option").map(Self.option)
            if !block.values("color").isEmpty {
                control = .swatches(block.values("color"), value: block.value("value"))
            } else {
                control = .menu(options, value: block.value("value"))
            }
        case "number":
            control = .metric(block.value("value") ?? "")
        default:
            control = .none
        }
        mark = control == .none && kind == "text" ? Self.mark(block) : nil
    }

    private static func hex(_ text: String) -> String? {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit) ? text : nil
    }

    private static func mark(_ block: TextBlock) -> MetricValue? {
        let points = block.values("point").compactMap(Double.init).filter(\.isFinite)
        let value = block.number("value")
        guard value != nil || !points.isEmpty else { return nil }
        return MetricValue(
            title: block.value("detail") ?? "",
            tone: block.value("tone").flatMap(MetricValue.Tone.init),
            value: value,
            points: points.isEmpty ? nil : points,
            max: block.number("max")
        )
    }

    /// The good, warn or bad tone of a text, which colours its words. Another part shows its tone in its own way.
    public var textTone: MetricValue.Tone? {
        kind == "text" && tone != .on ? tone : nil
    }

    /// Reads an `option` line, `<id>:<title>[:<icon>]`, or an id that is its own title. The icon follows the last colon, so
    /// a title with an icon keeps each colon of its own.
    static func option(_ text: String) -> Option {
        guard let first = text.firstIndex(of: ":") else { return Option(id: text, title: text) }
        let rest = text[text.index(after: first)...]
        guard let last = rest.lastIndex(of: ":") else { return Option(id: String(text[..<first]), title: String(rest)) }
        return Option(id: String(text[..<first]), title: String(rest[..<last]), icon: String(rest[rest.index(after: last)...]))
    }

    /// The value of its control, as the script reads it. A line with no control has none.
    public var value: String? {
        switch control {
        case .none, .metric, .chart, .image, .progress: nil
        case .toggle(let on): on ? "true" : "false"
        case .slider(let level, _, _): String(Int(level.rounded()))
        case .swatches(_, let value), .menu(_, let value), .list(_, let value): value
        case .text(let text, _, _): text
        case .shortcut(let text): text
        }
    }

    /// This part as a drawing places it: a choice whose area covers more than one line is a list, and any other is a menu.
    public func drawn(in layout: SheetLayout?) -> SpotPart {
        guard case .menu(let options, let value) = control, let area = layout?.areas[id], area.y1 > area.y0 else { return self }
        var part = self
        part.control = .list(options, value: value)
        return part
    }

    /// The words in the ring of a level, which takes the place of its detail: the detail with no percent sign.
    public var ringWords: String? {
        guard mark?.kind == .gauge, let detail else { return nil }
        return detail.hasSuffix("%") ? String(detail.dropLast()) : detail
    }

    /// Whether it draws a block that takes all the height of its cell.
    public var fillsHeight: Bool {
        if kind == "view" { return true }
        return switch control {
        case .text, .list, .metric, .chart, .image, .progress: true
        default: look == .pad
        }
    }

    /// Whether it takes all the width of its cell. A small button or a menu keeps its own size.
    public var fillsWidth: Bool {
        if look == .chip || look == .bare { return title != nil && control != .none }
        if case .symbol = press, title == nil, control == .none { return false }
        return true
    }

    /// Whether it can scroll by itself, which rules out a sheet that scrolls around it.
    public var scrollsItself: Bool {
        switch control {
        case .text, .list: true
        default: false
        }
    }

    /// Whether its rows share the free height of a sheet.
    var growsRow: Bool {
        if kind == "view" { return true }
        return switch control {
        case .text, .list, .chart, .image: true
        default: false
        }
    }

    /// Whether a press reaches it, so that a press also stops its running call.
    public var isPressable: Bool {
        press != .none
    }

    /// Whether the person types into it.
    public var isEditable: Bool {
        if case .text(_, _, false) = control { return true }
        return false
    }

    /// Whether the return key can use it.
    public var isSelectable: Bool {
        switch control {
        case .toggle, .shortcut: true
        default: press != .none
        }
    }

    /// Takes a value that the person set.
    public mutating func set(_ value: String) {
        switch control {
        case .none, .metric, .chart, .image, .progress: break
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
