import Foundation

extension Style {
    private static let steps = [
        "0", "0.5", "1", "1.5", "2", "2.5", "3", "3.5", "4", "5", "6", "7", "8", "9", "10", "11", "12", "14", "16", "20",
        "24", "28", "32", "36", "40", "44", "48", "52", "56", "60", "64", "72", "80", "96"
    ]
    private static let fractions: [String: Double] = ["1/2": 1.0 / 2, "1/3": 1.0 / 3, "2/3": 2.0 / 3, "1/4": 1.0 / 4, "3/4": 3.0 / 4]
    private static let counts = 1...12
    private static let opacityStep = 5

    public init(classes: String) {
        self.init()
        for word in classes.split(whereSeparator: \.isWhitespace) {
            var pieces = word.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            let base = pieces.removeLast()
            let prefixes = pieces.compactMap(Variant.init(rawValue:))
            let isKnown = prefixes.count == pieces.count
                && (prefixes.isEmpty ? take(base) : variants[Set(prefixes), default: Style()].take(base))
            if !isKnown { unknown.append(String(word)) }
        }
        variants = variants.filter { $0.value != Style() }
        named = variants.keys.reduce(into: []) { $0.formUnion($1) }
    }

    private mutating func take(_ word: String) -> Bool {
        switch word {
        case "flex-row": arrangement = .row
        case "flex-col": arrangement = .column
        case "grid": arrangement = .grid
        case "relative": arrangement = .layers
        case "absolute": isAbsolute = true
        case "inset-0": pins = Set(Edge.allCases)
        case "top-0": pins.insert(.top)
        case "right-0": pins.insert(.right)
        case "bottom-0": pins.insert(.bottom)
        case "left-0": pins.insert(.left)
        case "hidden": isHidden = true
        case "flex": isHidden = false
        case "items-start": items = .start
        case "items-center": items = .center
        case "items-end": items = .end
        case "items-stretch": items = .stretch
        case "justify-start": justify = .start
        case "justify-center": justify = .center
        case "justify-end": justify = .end
        case "justify-between": justify = .between
        case "self-start": alignSelf = .start
        case "self-center": alignSelf = .center
        case "self-end": alignSelf = .end
        case "self-stretch": alignSelf = .stretch
        case "grow": grows = true
        case "shrink-0": shrinks = false
        case "aspect-square": isSquare = true
        case "font-title": font = .title
        case "font-detail": font = .detail
        case "font-metric": font = .metric
        case "font-value": font = .value
        case "font-section": font = .section
        case "font-medium": weight = .medium
        case "font-semibold": weight = .semibold
        case "font-bold": weight = .bold
        case "text-left": textAlignment = .left
        case "text-center": textAlignment = .center
        case "text-right": textAlignment = .right
        case "truncate": truncates = true
        case "sr-only": hidesWords = true
        case "tabular-nums": tabularNumbers = true
        case "animate-pulse": pulses = true
        case "animate-layout": animatesLayout = true
        case "overflow-y-auto": scrolls = true
        case "text-ink": ink = .ink
        case "text-secondary": ink = .secondary
        case "text-accent": ink = .accent
        case "text-good": ink = .good
        case "text-warn": ink = .warn
        case "text-bad": ink = .bad
        case "bg-tile": fill = .tile
        case "bg-accent": fill = .accent
        case "bg-good": fill = .good
        case "bg-warn": fill = .warn
        case "bg-bad": fill = .bad
        case "bg-transparent": fill = .transparent
        case "backdrop-blur": blursBackdrop = true
        case "rounded-card": corner = .card
        case "rounded-inner": corner = .inner
        case "rounded-full": corner = .full
        case "rounded-none": corner = .none
        case "border": hasBorder = true
        case "overflow-hidden": clips = true
        default: return take(scaled: word)
        }
        return true
    }

    private mutating func take(scaled word: String) -> Bool {
        if let value = Self.value(of: word, after: "gap-x-") { return Self.put(Self.space(value), in: &columnGap) }
        if let value = Self.value(of: word, after: "gap-y-") { return Self.put(Self.space(value), in: &rowGap) }
        if let value = Self.value(of: word, after: "gap-"), let space = Self.space(value) {
            columnGap = space
            rowGap = space
            return true
        }
        let sides: [(String, [Edge])] = [
            ("p-", Edge.allCases), ("px-", [.left, .right]), ("py-", [.top, .bottom]),
            ("pt-", [.top]), ("pr-", [.right]), ("pb-", [.bottom]), ("pl-", [.left])
        ]
        for (prefix, edges) in sides {
            guard let value = Self.value(of: word, after: prefix) else { continue }
            guard let space = Self.space(value) else { return false }
            for edge in edges { padding[edge] = space }
            return true
        }
        if let value = Self.value(of: word, after: "size-"), let size = Self.size(value) {
            width = size
            height = size
            return true
        }
        if let value = Self.value(of: word, after: "w-") { return Self.put(Self.size(value), in: &width) }
        if let value = Self.value(of: word, after: "h-") { return Self.put(Self.size(value), in: &height) }
        if let value = Self.value(of: word, after: "min-w-") { return Self.put(Self.size(value), in: &minWidth) }
        if let value = Self.value(of: word, after: "max-w-") { return Self.put(Self.size(value), in: &maxWidth) }
        if let value = Self.value(of: word, after: "min-h-") { return Self.put(Self.size(value), in: &minHeight) }
        if let value = Self.value(of: word, after: "grid-cols-") { return Self.put(Self.count(value), in: &columns) }
        if let value = Self.value(of: word, after: "col-span-") { return Self.put(Self.count(value), in: &columnSpan) }
        if let value = Self.value(of: word, after: "row-span-") { return Self.put(Self.count(value), in: &rowSpan) }
        if let value = Self.value(of: word, after: "line-clamp-") { return Self.put(Self.count(value), in: &lineLimit) }
        if let value = Self.value(of: word, after: "opacity-") { return Self.put(Self.share(value), in: &opacity) }
        return false
    }

    private static func value(of word: String, after prefix: String) -> String? {
        word.hasPrefix(prefix) ? String(word.dropFirst(prefix.count)) : nil
    }

    private static func put<Value>(_ value: Value?, in slot: inout Value?) -> Bool {
        guard let value else { return false }
        slot = value
        return true
    }

    private static func space(_ value: String) -> Length? {
        switch value {
        case "part": .part
        case "group": .group
        default: steps.contains(value) ? Double(value).map(Length.steps) : nil
        }
    }

    private static func size(_ value: String) -> Length? {
        if value == "full" { return .full }
        if value == "px" { return .line }
        if let share = fractions[value] { return .fraction(share) }
        return steps.contains(value) ? Double(value).map(Length.steps) : nil
    }

    private static func count(_ value: String) -> Int? {
        Int(value).flatMap { counts.contains($0) && String($0) == value ? $0 : nil }
    }

    private static func share(_ value: String) -> Double? {
        Int(value).flatMap { (0...100).contains($0) && $0 % opacityStep == 0 && String($0) == value ? Double($0) / 100 : nil }
    }
}
