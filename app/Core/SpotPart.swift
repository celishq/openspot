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
        case tile, chip, strong, bare, section, key
    }

    public enum Align: String, Equatable, Sendable {
        case left, center, right
    }

    public let id: String
    public let isSection: Bool
    public let title: String?
    public let detail: String?
    public let symbol: String?
    public private(set) var control: Control
    public let press: Press
    public let key: ActionKey?
    public let closes: Bool
    public let cell: String?
    public let align: Align?
    public let look: Look?

    /// Reads a block with a `part` or a `section` key.
    public init?(block: TextBlock) {
        guard let id = block.value("part") ?? block.value("section") else { return nil }
        self.id = id
        isSection = block.value("section") != nil
        title = block.value("title")
        detail = block.value("detail")
        symbol = block.value("symbol")
        key = block.value("key").flatMap(ActionKey.init(text:))
        closes = block.flag("close") ?? false
        cell = block.value("cell")
        align = block.value("align").flatMap(Align.init(rawValue:))
        look = block.value("look").flatMap(Look.init(rawValue:))
        switch block.value("press") {
        case nil: press = .none
        case "true": press = .line
        case let name?: press = .symbol(name)
        }
        if let on = block.flag("on") {
            control = .toggle(on)
        } else if block.value("block") == "progress" {
            control = .progress(level: block.number("level") ?? 0)
        } else if let shortcut = block.value("shortcut") {
            control = .shortcut(shortcut)
        } else if let metric = block.value("metric") {
            control = .metric(metric)
        } else if let image = block.value("image") {
            control = .image(image)
        } else if !block.values("point").isEmpty {
            control = .chart(block.values("point").compactMap(Double.init))
        } else if !block.values("item").isEmpty {
            control = .list(block.values("item").map(Self.option), value: block.value("value"))
        } else if let level = block.number("level") {
            control = .slider(level: level, min: block.number("min") ?? 0, max: block.number("max") ?? 100)
        } else if !block.values("color").isEmpty {
            control = .swatches(block.values("color"), value: block.value("value"))
        } else if !block.values("option").isEmpty {
            control = .menu(block.values("option").map(Self.option), value: block.value("value"))
        } else if block.fields.contains(where: { $0.key == "text" }) {
            control = .text(
                block.value("text") ?? "",
                placeholder: block.value("placeholder"),
                isReadOnly: block.flag("readonly") ?? false
            )
        } else {
            control = .none
        }
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

    /// Whether it draws a block that takes all the height of its cell.
    public var fillsHeight: Bool {
        switch control {
        case .text, .list, .metric, .chart, .image, .progress: true
        default: look == .key
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
        switch control {
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
