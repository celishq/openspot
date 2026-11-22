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
    public let isOpen: Bool
    public let title: String?
    public let detail: String?
    public let symbol: String?
    public let tone: MetricValue.Tone?
    public let color: String?
    public private(set) var control: Control
    public let press: Press
    public let key: ActionKey?
    public let asksToRecord: Bool
    public let closes: Bool
    public let align: Align?
    public let look: Look?
    public private(set) var values: [String: [String]]

    public private(set) var items: [[String]] = []

    func holding(items: [[String]]) -> SpotPart {
        guard isOpen, !items.isEmpty else { return self }
        var part = self
        part.items = items
        return part
    }

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
        isOpen = kind.isOpen
        values = kind.isOpen ? Dictionary(grouping: block.fields, by: \.key).mapValues { $0.map(\.value) } : [:]
        title = block.value("title")
        detail = block.value("detail")
        key = kind == .hotkey ? nil : block.value("shortcut").flatMap(ActionKey.init(text:))
        asksToRecord = kind == .hotkey && block.flag("recording") == true
        closes = block.flag("close") ?? kind.presses
        align = block.value("align").flatMap(Align.init(rawValue:))
        let named = block.value("look").flatMap(Look.init(rawValue:))
        look = block.value("type").flatMap { kind.looks[$0] } ?? (named == .tick ? nil : named)
        let icon = Icon(text: block.value("icon"))
        tone = block.value("tone").flatMap(MetricValue.Tone.init)
        color = kind.takesColor ? block.value("color").flatMap { BlockKind.isColor($0) ? $0 : nil } : nil
        symbol = kind.presses ? nil : icon?.symbol
        press = kind.presses ? icon?.symbol.map(Press.symbol) ?? .line : .none
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

    public func numberLook(columns: Double, rows: Double) -> NumberLook? {
        number.map { NumberLook(reading: $0, columns: columns, rows: rows) }
    }

    public func numberLook(inSheet size: CGSize) -> NumberLook? {
        numberLook(columns: size.width / SpotTokens.cell, rows: size.height / SpotTokens.cell)
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

    func drawn(spanning isTall: Bool) -> SpotPart {
        guard case .menu(let options, let value) = control, isTall else { return self }
        var part = self
        part.control = .list(options, value: value)
        return part
    }

    public var fillsHeight: Bool {
        if isOpen { return true }
        return switch control {
        case .text, .list, .number, .image: true
        default: false
        }
    }

    public var fillsWidth: Bool {
        if look == .chip || look == .bare { return title != nil && control != .none }
        if case .symbol = press, title == nil, control == .none { return false }
        return true
    }

    public var flatLines: Int {
        if case .shortcut = control { return 2 }
        return 1
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
