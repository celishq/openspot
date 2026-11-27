import Observation
import SwiftUI

@MainActor
@Observable
final class PageScroll {
    var isTitleShown = false
    var isScrolled = false
    var barHeight: CGFloat = 0
    @ObservationIgnored private var kept: [String: CGFloat] = [:]
    @ObservationIgnored private var order: [String] = []
    private static let limit = 64

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

    func keep(_ offset: CGFloat, of page: String) {
        if kept.updateValue(offset, forKey: page) == nil { order.append(page) }
        if order.count > Self.limit { kept[order.removeFirst()] = nil }
    }

    func offset(of page: String) -> CGFloat {
        kept[page] ?? 0
    }

    func take(barHeight height: CGFloat) {
        guard height != barHeight else { return }
        barHeight = height
    }
}
