import Foundation

/// One line of a sheet that a script prints. What the block holds decides what it shows.
public struct SpotPart: Equatable, Sendable, Identifiable {
    public struct Option: Equatable, Sendable {
        public let id: String
        public let title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
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

    /// A look from the one set that the app owns. A script cannot set a size or a colour of its own.
    public enum Look: String, Equatable, Sendable {
        case tile, chip, strong, bare, section, pad, large, list
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
    public static let kinds = ["text", "gauge", "graph", "picture", "view", "spot", "switch", "slider", "field", "choice", "shortcut", "button", "section"]

    /// Reads a block whose first key is a kind of part. Its value is the id, and the kind decides the control.
    public init?(block: TextBlock) {
        guard let kind = block.fields.first?.key, Self.kinds.contains(kind), let id = block.value(kind) else { return nil }
        self.id = id
        self.kind = kind
        isSection = kind == "section"
        let isLarge = kind == "text" && block.value("look") == "large"
        title = isLarge ? block.value("detail") : block.value("title")
        detail = isLarge ? nil : block.value("detail")
        key = kind == "shortcut" ? nil : block.value("shortcut").flatMap(ActionKey.init(text:))
        closes = block.flag("close") ?? false
        align = block.value("align").flatMap(Align.init(rawValue:))
        look = block.value("look").flatMap(Look.init(rawValue:))
        let symbol = block.value("symbol")
        file = block.value("file")
        glyph = block.value("glyph")
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
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
            control = block.value("image").map(Control.image) ?? .none
        case "slider":
            control = .slider(level: block.number("level") ?? 0, min: block.number("min") ?? 0, max: block.number("max") ?? 100)
        case "field":
            control = .text(block.value("text") ?? "", placeholder: block.value("placeholder"), isReadOnly: block.flag("readonly") ?? false)
        case "shortcut":
            control = .shortcut(block.value("value") ?? "")
        case "choice":
            let options = block.values("option").map(Self.option)
            if !block.values("color").isEmpty {
                control = .swatches(block.values("color"), value: block.value("value"))
            } else if block.value("look") == "list" {
                control = .list(options, value: block.value("value"))
            } else {
                control = .menu(options, value: block.value("value"))
            }
        case "text" where isLarge:
            control = .metric(block.value("title") ?? "")
        default:
            control = .none
        }
        mark = control == .none && kind == "text" ? Self.mark(block) : nil
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

    private static func option(_ text: String) -> Option {
        let pair = text.split(separator: ":", maxSplits: 1).map(String.init)
        return Option(id: pair[0], title: pair.count > 1 ? pair[1] : pair[0])
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
