import OpenspotCore

@MainActor
final class LookPalettes {
    static let shared = LookPalettes()
    private static let limit = 32

    private var kept: [String: (colours: Theme.Colours, palette: SpotPalette)] = [:]

    func palette(of look: ListedTheme) -> SpotPalette {
        if let found = kept[look.id], found.colours == look.colours { return found.palette }
        if kept.count >= Self.limit { kept.removeAll() }
        let palette = SpotPalette(look.colours)
        kept[look.id] = (look.colours, palette)
        return palette
    }
}
