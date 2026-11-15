import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
    @Entry var spotPanels = GridPanels()
    @Entry var spotFade = 1.0
    @Entry var spotScrollFade: SpotEdgeFade?
    @Entry var spotDrawsGlass = true
    @Entry var spotIsHeld = false
}

enum SpotMotion {
    static func grow(isOpen: Bool) -> Animation {
        isOpen ? .spring(duration: MotionTokens.grow, bounce: 0) : .timingCurve(0.2, 0.1, 0.2, 1, duration: MotionTokens.shrink)
    }

    static let move = Animation.spring(duration: MotionTokens.move, bounce: 0)

    static func fade(isShown: Bool) -> Animation {
        .easeOut(duration: isShown ? MotionTokens.fadeIn : MotionTokens.fadeOut)
    }

    static let press = Animation.spring(duration: MotionTokens.press, bounce: MotionTokens.pressBounce)

    static func animation(_ motion: PanelMotion) -> Animation {
        switch motion {
        case .sheet(let isOpen): grow(isOpen: isOpen)
        case .edit: move
        case .flow: grow(isOpen: true)
        case .fade: fade(isShown: true)
        }
    }
}
