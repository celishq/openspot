import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
    /// Whether a blur of the desktop draws. A picture turns it off, since the system blur draws grey into a picture.
    @Entry var spotDrawsBlur = true
    /// The width of the panel, which its grid's columns set.
    @Entry var spotPanelWidth = SpotTokens.panelWidth
}

/// The five curves of the app, one for each kind of motion, from the numbers of `MotionTokens`. A part of a surface that
/// grows takes its look from the surface's progress, by `SheetMorph`, and no curve of its own.
enum SpotMotion {
    /// A surface that grows out of its source, or goes back into it. The way back lies on its source when it completes,
    /// when the source takes its place.
    static func grow(isOpen: Bool) -> Animation {
        isOpen ? .spring(duration: MotionTokens.grow, bounce: 0) : .timingCurve(0.2, 0.1, 0.2, 1, duration: MotionTokens.shrink)
    }

    /// A thing that moves in place.
    static let move = Animation.spring(duration: MotionTokens.move, bounce: 0)

    /// A thing that shows or hides in place.
    static func fade(isShown: Bool) -> Animation {
        .easeOut(duration: isShown ? MotionTokens.fadeIn : MotionTokens.fadeOut)
    }

    /// The answer to a press, and a mark that arrives.
    static let press = Animation.spring(duration: MotionTokens.press, bounce: MotionTokens.pressBounce)

    /// The curve of a motion that the model starts.
    static func animation(_ motion: PanelMotion) -> Animation {
        switch motion {
        case .sheet(let isOpen): grow(isOpen: isOpen)
        case .edit: move
        case .fade: fade(isShown: true)
        }
    }
}
