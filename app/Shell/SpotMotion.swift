import SwiftUI

extension EnvironmentValues {
    @Entry var spotIsShown = true
}

/// The timing of the panel and its sheet: on close fill, text and backdrop fade first, and the rims last.
/// Open fades everything in together.
enum SpotMotion {
    static let openDuration = 0.15
    static let fadeInDuration = 0.1
    static let fadeOutDuration = 0.12
    static let closeDuration = 0.2
    static let hiddenScale = 1.04
    static let backdropHiddenScale = 1.02
    static let pressedScale = 1.04
    static let pushedScale = 0.92
    static let pressedGlass = 1.5
    static let press = Animation.spring(duration: 0.2, bounce: 0.2)
    static let follow = Animation.easeOut(duration: 0.2)
    static let arrowScroll = Animation.smooth(duration: 0.18)
    static let keycap = Animation.easeOut(duration: 0.12)
    static let edit = Animation.spring(duration: 0.3, bounce: 0)
    static let hintFade = Animation.easeOut(duration: 0.15)
    static let cardFadeDuration = 0.06
    /// How strong a card stays under an open sheet: too faint to see, but drawn, so its return redraws nothing.
    static let coveredCardOpacity = 0.001

    static func sheet(isOpen: Bool) -> Animation {
        .spring(duration: isOpen ? openDuration : closeDuration, bounce: 0)
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

    /// The field's words leave in the first quarter of a sheet's motion.
    static func wordsOut(isOpen: Bool) -> Animation {
        .easeOut(duration: (isOpen ? openDuration : closeDuration) / 4)
    }

    /// The field's words return in the second half of a sheet's motion, a quarter after they have left.
    static func wordsIn(isOpen: Bool) -> Animation {
        let duration = isOpen ? openDuration : closeDuration
        return .easeIn(duration: duration / 2).delay(duration / 4)
    }

    /// How a card fades: out as the edge of an opening sheet comes over it, and back in as the edge of a closing sheet
    /// leaves it, so that the fade runs with the sheet's edge out to the window's edge. `reach` is from `SheetGrowth`.
    static func cardFade(isSheetOpen: Bool, reach: Double) -> Animation {
        guard !isSheetOpen else {
            return .easeOut(duration: cardFadeDuration).delay(max(sheetTime(isOpen: true, share: reach) - cardFadeDuration, 0))
        }
        return .easeOut(duration: cardFadeDuration).delay(sheetTime(isOpen: false, share: 1 - reach))
    }

    /// When the spring of `sheet(isOpen:)` has moved the sheet this share of its way.
    static func sheetTime(isOpen: Bool, share: Double) -> Double {
        let duration = isOpen ? openDuration : closeDuration
        let pace = 2 * Double.pi / duration
        var range = (0.0, duration * 2)
        for _ in 0..<24 {
            let time = (range.0 + range.1) / 2
            if 1 - (1 + pace * time) * exp(-pace * time) < share { range.0 = time } else { range.1 = time }
        }
        return range.0
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
