import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
    @Entry var spotPanels = GridPanels()
    @Entry var spotFade = 1.0
    #if OPENSPOT_TOOLS
    @Entry var spotDrawsGlass = SpotMotionProbe.drawsGlass
    #else
    @Entry var spotDrawsGlass = true
    #endif
    @Entry var spotIsHeld = false
    @Entry var spotIsStill = false
}

enum SpotMotion {
    static func grow(isOpen: Bool) -> Animation {
        isOpen ? .spring(duration: MotionTokens.grow, bounce: 0) : .timingCurve(MotionTokens.shrinkCurve.x1, MotionTokens.shrinkCurve.y1, MotionTokens.shrinkCurve.x2, MotionTokens.shrinkCurve.y2, duration: MotionTokens.shrink)
    }

    static var move: Animation { .spring(duration: MotionTokens.move, bounce: 0) }

    static func fade(isShown: Bool) -> Animation {
        .easeOut(duration: isShown ? MotionTokens.fadeIn : MotionTokens.fadeOut)
    }

    static var press: Animation { .spring(duration: MotionTokens.press, bounce: MotionTokens.pressBounce) }

    static func animation(_ motion: PanelMotion) -> Animation {
        switch motion {
        case .sheet(let isOpen): grow(isOpen: isOpen)
        case .edit: move
        case .flow: grow(isOpen: true)
        case .fade: fade(isShown: true)
        }
    }
}
