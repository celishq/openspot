import Foundation

extension Style {
    public func resolved(for active: Set<Variant>) -> Style {
        guard !named.isDisjoint(with: active) else { return self }
        let applied = variants.filter { $0.key.isSubset(of: active) }.sorted { left, right in
            left.key.count != right.key.count ? left.key.count < right.key.count : Self.rank(left.key).lexicographicallyPrecedes(Self.rank(right.key))
        }
        return applied.reduce(self) { $0.taking($1.value) }
    }

    private static func rank(_ variants: Set<Variant>) -> [Int] {
        variants.compactMap { Variant.allCases.firstIndex(of: $0) }.sorted()
    }

    private func taking(_ other: Style) -> Style {
        var next = self
        next.arrangement = other.arrangement ?? arrangement
        next.isHidden = other.isHidden ?? isHidden
        next.columns = other.columns ?? columns
        next.columnSpan = other.columnSpan ?? columnSpan
        next.rowSpan = other.rowSpan ?? rowSpan
        next.isAbsolute = other.isAbsolute || isAbsolute
        next.pins = pins.union(other.pins)
        next.items = other.items ?? items
        next.justify = other.justify ?? justify
        next.alignSelf = other.alignSelf ?? alignSelf
        next.padding = padding.merging(other.padding) { $1 }
        next.columnGap = other.columnGap ?? columnGap
        next.rowGap = other.rowGap ?? rowGap
        next.width = other.width ?? width
        next.height = other.height ?? height
        next.minWidth = other.minWidth ?? minWidth
        next.maxWidth = other.maxWidth ?? maxWidth
        next.grows = other.grows ?? grows
        next.shrinks = other.shrinks ?? shrinks
        next.isSquare = other.isSquare || isSquare
        next.font = other.font ?? font
        next.weight = other.weight ?? weight
        next.textAlignment = other.textAlignment ?? textAlignment
        next.truncates = other.truncates || truncates
        next.hidesWords = other.hidesWords || hidesWords
        next.lineLimit = other.lineLimit ?? lineLimit
        next.tabularNumbers = other.tabularNumbers || tabularNumbers
        next.ink = other.ink ?? ink
        next.fill = other.fill ?? fill
        next.blursBackdrop = other.blursBackdrop || blursBackdrop
        next.opacity = other.opacity ?? opacity
        next.corner = other.corner ?? corner
        next.hasBorder = other.hasBorder || hasBorder
        next.clips = other.clips || clips
        return next
    }
}

extension Style.Variant {
    public init?(size: SpotSize) {
        self.init(rawValue: size.name)
    }

    public static func card(_ size: SpotSize) -> Set<Style.Variant> {
        Set([.card] + [Style.Variant(size: size)].compactMap { $0 })
    }
}
