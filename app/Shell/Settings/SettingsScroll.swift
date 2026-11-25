import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsScroll {
    var isTitleShown = false
    var isScrolled = false
    var barHeight: CGFloat = 0

    func show(title isShown: Bool) {
        guard isShown != isTitleShown else { return }
        withAnimation(SpotMotion.fade(isShown: isShown)) { isTitleShown = isShown }
    }

    func show(bar isShown: Bool) {
        guard isShown != isScrolled else { return }
        withAnimation(SpotMotion.fade(isShown: isShown)) { isScrolled = isShown }
    }

    func reset() {
        if isTitleShown { isTitleShown = false }
        if isScrolled { isScrolled = false }
    }

    func take(barHeight height: CGFloat) {
        guard height != barHeight else { return }
        barHeight = height
    }
}
