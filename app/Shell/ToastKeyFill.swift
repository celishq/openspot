import SwiftUI

/// Draws a text with a rounded fill behind each run marked as a key.
struct ToastKeyFill: TextRenderer {
    /// Marks a run of a text as a key.
    struct Key: TextAttribute {}

    private static let radius: CGFloat = 4
    private static let padding: CGFloat = 3
    let fill: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[Key.self] != nil {
                    let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                    context.fill(shape.path(in: run.typographicBounds.rect.insetBy(dx: -Self.padding, dy: 0)), with: .color(fill))
                }
                context.draw(run)
            }
        }
    }
}
