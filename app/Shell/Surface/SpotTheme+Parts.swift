import SwiftUI

extension SpotTheme {
    static let mask = Color.black
    static let stale = 0.5
    static let oldBar = 0.55
    static let pressFill = 0.12
    static let menuBarTrack = 0.25
    static let fadeNear = 0.6
    static let fadeFar = 0.2
    static let fadeSteps = 3.0
    static let liftShadowColor = Color.black
    static let liftShadowDrop: CGFloat = 4

    static let foilBase = Color.white
    static let publisherRim = Color.white.opacity(0.3)
    static let publisherPill = 0.1
    static let publisherPillHover = 0.18
    static let publisherPillRing = 0.22
    static let publisherPillShine = Color.white.opacity(0.45)
    static let engraveDark = Color(red: 236 / 255, green: 238 / 255, blue: 244 / 255).opacity(0.9)
    static let engraveLight = Color(red: 18 / 255, green: 20 / 255, blue: 26 / 255).opacity(0.8)
    static let catchLightDark = Color.black.opacity(0.6)
    static let catchLightLight = Color.white.opacity(0.55)
}
