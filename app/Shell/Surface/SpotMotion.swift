import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
    @Entry var spotDrawsBlur = true
    @Entry var spotPanels = GridPanels()
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
        case .edit, .push: move
        case .fade: fade(isShown: true)
        }
    }
}
