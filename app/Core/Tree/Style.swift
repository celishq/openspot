import Foundation

public struct Style: Equatable, Sendable {
    public enum Arrangement: Equatable, Sendable {
        case column, row, layers, grid
    }

    public enum Edge: CaseIterable, Hashable, Sendable {
        case top, right, bottom, left
    }

    public enum Alignment: Equatable, Sendable {
        case start, center, end, stretch
    }

    public enum Justification: Equatable, Sendable {
        case start, center, end, between
    }

    public enum Length: Equatable, Sendable {
        case steps(Double)
        case part
        case group
        case line
        case full
        case fraction(Double)

        public func points(of whole: CGFloat) -> CGFloat {
            switch self {
            case .steps(let count): CGFloat(count) * SpotTokens.spaceUnit
            case .part: SpotTokens.partGap
            case .group: SpotTokens.partGroupGap
            case .line: SpotTokens.dividerHeight
            case .full: whole
            case .fraction(let share): whole * CGFloat(share)
            }
        }
    }

    public enum Font: Equatable, Sendable {
        case title, detail, metric, value, section
    }

    public enum Weight: Equatable, Sendable {
        case medium, semibold, bold
    }

    public enum TextAlignment: Equatable, Sendable {
        case left, center, right
    }

    public enum Ink: Equatable, Sendable {
        case ink, secondary, accent, good, warn, bad
    }

    public enum Fill: Equatable, Sendable {
        case tile, accent, good, warn, bad, transparent
    }

    public enum Corner: Equatable, Sendable {
        case card, inner, full, none
    }

    public enum Variant: String, CaseIterable, Hashable, Sendable {
        case sheet, card, bar, float, window
        case small, wide, square, strip, large
        case hover, pressed, selected, focus
        case dark, light
    }

    public var arrangement: Arrangement?
    public var isHidden: Bool?
    public var columns: Int?
    public var columnSpan: Int?
    public var rowSpan: Int?
    public var isAbsolute = false
    public var pins: Set<Edge> = []
    public var items: Alignment?
    public var justify: Justification?
    public var alignSelf: Alignment?
    public var padding: [Edge: Length] = [:]
    public var columnGap: Length?
    public var rowGap: Length?
    public var width: Length?
    public var height: Length?
    public var minWidth: Length?
    public var maxWidth: Length?
    public var minHeight: Length?
    public var grows: Bool?
    public var shrinks: Bool?
    public var isSquare = false
    public var font: Font?
    public var weight: Weight?
    public var textAlignment: TextAlignment?
    public var truncates = false
    public var hidesWords = false
    public var lineLimit: Int?
    public var tabularNumbers = false
    public var pulses = false
    public var animatesLayout = false
    public var scrolls = false
    public var ink: Ink?
    public var fill: Fill?
    public var blursBackdrop = false
    public var opacity: Double?
    public var corner: Corner?
    public var hasBorder = false
    public var clips = false
    public var variants: [Set<Variant>: Style] = [:]
    public var named: Set<Variant> = []
    public var unknown: [String] = []

    public init() {}

    var insets: CGSize {
        let side = { (edge: Edge) in padding[edge]?.points(of: 0) ?? 0 }
        return CGSize(width: side(.left) + side(.right), height: side(.top) + side(.bottom))
    }
}
