import SwiftUI

extension SpotTheme {
    static let mask = Color.black
    @MainActor static var stale: Double { loaded.shared.stale }
    @MainActor static var oldBar: Double { loaded.shared.oldBar }
    @MainActor static var pressFill: Double { loaded.shared.pressFill }
    @MainActor static var menuBarTrack: Double { loaded.shared.menuBarTrack }
    @MainActor static var fadeNear: Double { loaded.shared.fadeNear }
    @MainActor static var fadeFar: Double { loaded.shared.fadeFar }
    static let fadeSteps = 3.0
    @MainActor static var liftShadowColor: Color { loaded.liftShadow }
    static let liftShadowDrop: CGFloat = 4

    @MainActor static var foilBase: Color { loaded.foil }
    @MainActor static var publisherRim: Color { loaded.publisherRim }
    @MainActor static var publisherPill: Double { loaded.shared.publisherPill }
    @MainActor static var publisherPillHover: Double { loaded.shared.publisherPillHover }
    @MainActor static var publisherPillRing: Double { loaded.shared.publisherPillRing }
    @MainActor static var publisherPillShine: Color { loaded.publisherPillShine }
    @MainActor static var engraveDark: Color { loaded.engraveOnDark }
    @MainActor static var engraveLight: Color { loaded.engraveOnLight }
    @MainActor static var catchLightDark: Color { loaded.catchLightOnDark }
    @MainActor static var catchLightLight: Color { loaded.catchLightOnLight }
}
