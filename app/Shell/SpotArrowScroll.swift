import OpenspotCore
import SwiftUI

/// Scrolls a sheet by one row for each arrow press, and stops at its ends. It alone reads the presses, so that a held key
/// moves only the scroll and redraws nothing else.
struct SpotArrowScroll: ViewModifier {
    let nudge: () -> SpotPanel.Nudge
    @State private var position = ScrollPosition(edge: .top)
    @State private var limit: CGFloat = 0
    @State private var aim: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self, of: { max($0.contentSize.height - $0.containerSize.height, 0) }, action: { _, room in limit = room })
            .onScrollPhaseChange { _, phase, context in
                if phase == .idle { aim = context.geometry.contentOffset.y }
            }
            .onChange(of: nudge()) { _, nudge in
                let row = SheetPlacement.rowHeight + SheetPlacement.gap
                aim = min(max(aim + CGFloat(nudge.step) * row, 0), limit)
                withAnimation(SpotMotion.arrowScroll) { position.scrollTo(y: aim) }
            }
    }
}
