import SwiftUI

/// Draws a text with a capsule behind each run marked as a key, as the footer draws its keys.
struct ToastKeyFill: TextRenderer {
    /// Marks a run of a text as a key.
    struct Key: TextAttribute {}

    private static let thinSpace: CGFloat = 2
    let fill: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[Key.self] != nil {
                    let rect = run.typographicBounds.rect.insetBy(dx: Self.thinSpace - SpotTokens.hintKeyPadding, dy: 0)
                    context.fill(Capsule().path(in: rect), with: .color(fill))
                }
                context.draw(run)
            }
        }
    }
}
