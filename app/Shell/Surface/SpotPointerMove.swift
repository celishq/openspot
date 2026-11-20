import AppKit
import SwiftUI

struct SpotPointerMove: ViewModifier {
    let action: (CGPoint?) -> Void

    init(_ action: @escaping () -> Void) {
        self.action = { if $0 != nil { action() } }
    }

    init(at action: @escaping (CGPoint?) -> Void) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            guard case .active(let place) = phase else { return action(nil) }
            let point = NSEvent.mouseLocation
            defer { SpotPointerPlace.last = point }
            if let last = SpotPointerPlace.last, last != point { action(place) }
        }
    }
}

@MainActor
private enum SpotPointerPlace {
    static var last: CGPoint?
}
