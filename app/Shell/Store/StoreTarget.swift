import AppKit
import SwiftUI

struct StoreTarget: NSViewRepresentable {
    let take: (CGRect) -> Void

    func makeNSView(context: Context) -> Anchor {
        Anchor(take: take)
    }

    func updateNSView(_ anchor: Anchor, context: Context) {
        anchor.take = take
        anchor.report()
    }

    final class Anchor: NSView {
        var take: (CGRect) -> Void

        init(take: @escaping (CGRect) -> Void) {
            self.take = take
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            report()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report()
        }

        func report() {
            guard let height = window?.contentView?.bounds.height else { return }
            let rect = convert(bounds, to: nil)
            take(CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height))
        }
    }
}
