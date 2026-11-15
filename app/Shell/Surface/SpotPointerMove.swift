import AppKit
import SwiftUI

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

@MainActor
private enum SpotPointerPlace {
    static var last: CGPoint?
}
