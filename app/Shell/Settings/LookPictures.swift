import Observation
import OpenspotCore
import SwiftUI

@MainActor
@Observable
final class LookPictures {
    struct Key: Equatable {
        let colours: Theme.Colours
        let layout: Theme.Layout
        let isDark: Bool
        let spots: [LookSpot]
    }

    static let shared = LookPictures()
    private static let limit = 64

    private var kept: [String: (key: Key, picture: Image)] = [:]

    func picture(of look: ListedTheme, isDark: Bool, spots: [LookSpot]) -> Image? {
        let key = Key(colours: look.colours, layout: look.layout, isDark: isDark, spots: spots)
        return kept["\(look.id)/\(isDark)"].flatMap { $0.key == key ? $0.picture : nil }
    }

    func draw(_ look: ListedTheme, isDark: Bool, spots: [LookSpot]) {
        let key = Key(colours: look.colours, layout: look.layout, isDark: isDark, spots: spots)
        let name = "\(look.id)/\(isDark)"
        guard kept[name]?.key != key else { return }
        let panel = LookPanel(swatch: isDark ? look.colours.dark : look.colours.light, layout: look.layout, spots: spots)
        let renderer = ImageRenderer(content: panel.environment(\.colorScheme, isDark ? .dark : .light))
        renderer.scale = SpotTokens.settingsLookPictureScale
        guard let image = renderer.cgImage else { return }
        if kept.count >= Self.limit { kept.removeAll() }
        kept[name] = (key, Image(decorative: image, scale: SpotTokens.settingsLookPictureScale))
    }
}
