import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
}

/// The timing of the panel and its sheet: on close fill, text and backdrop fade first, and the rims last.
/// Open fades everything in together.
enum SpotMotion {
    static let openDuration = SheetOpening.springDuration
    static let fadeInDuration = 0.1
    static let fadeOutDuration = 0.12
    static let closeDuration = 0.2
    static let hiddenScale = 1.04
    static let backdropHiddenScale = 1.02
    static let pressedScale = 1.04
    static let liftedScale = 1.05
    static let pushedScale = 0.4
    static let pressedGlass = 1.5
    static let press = Animation.spring(duration: 0.2, bounce: 0.2)
    static let follow = Animation.easeOut(duration: 0.2)
    static let arrowScroll = Animation.smooth(duration: 0.18)
    static let keycap = Animation.easeOut(duration: 0.12)
    static let edit = Animation.spring(duration: 0.3, bounce: 0)
    static let hintFade = Animation.easeOut(duration: 0.15)
    static let liftFade = Animation.easeOut(duration: 0.15)
    /// How strong a card stays under an open sheet: too faint to see, but drawn, so its return redraws nothing.
    static let coveredCardOpacity = 0.001

    static func sheet(isOpen: Bool) -> Animation {
        .spring(duration: isOpen ? openDuration : closeDuration, bounce: 0)
    }

    /// The spring of a motion that the model starts.
    static func animation(_ motion: PanelMotion) -> Animation {
        switch motion {
        case .sheet(let isOpen): sheet(isOpen: isOpen)
        case .edit: edit
        }
    }

    /// The change of an on card's fill: the first 40% of an open, and the last 55% of a close.
    static func fillFade(isOpen: Bool) -> Animation {
        isOpen ? .easeOut(duration: openDuration * 0.4) : .easeInOut(duration: closeDuration * 0.55).delay(closeDuration * 0.45)
    }

    /// The half of a sheet's motion that a part fades in, so that two looks of one place never overlap.
    static func sheetFade(isOpen: Bool, isLate: Bool) -> Animation {
        let half = (isOpen ? openDuration : closeDuration) / 2
        return isLate ? .easeIn(duration: half).delay(half) : .easeOut(duration: half)
    }

    /// The crossfade of the blur of the grid and the blur of the sheet.
    static func blurFade(isSheetOpen: Bool) -> Animation {
        .easeOut(duration: isSheetOpen ? openDuration : closeDuration)
    }

    static func surface(isShown: Bool) -> Animation {
        isShown ? .easeOut(duration: fadeInDuration) : .easeOut(duration: fadeOutDuration)
    }

    static func rim(isShown: Bool) -> Animation {
        isShown ? .easeOut(duration: fadeInDuration) : .easeIn(duration: fadeOutDuration)
    }
}
