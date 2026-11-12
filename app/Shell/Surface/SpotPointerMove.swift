import AppKit
import SwiftUI

/// Calls its action when the pointer moves over the view. A row that scrolls or appears under a still pointer calls
/// nothing, so that only a move of the hand moves the highlight.
struct SpotPointerMove: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            guard case .active = phase else { return }
            let point = NSEvent.mouseLocation
            defer { SpotPointerPlace.last = point }
            if let last = SpotPointerPlace.last, last != point { action() }
        }
    }
}

/// Where the pointer was at the last hover of any row.
@MainActor
private enum SpotPointerPlace {
    static var last: CGPoint?
}
