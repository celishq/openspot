import AppKit
import OpenspotCore
import SwiftUI

/// The square on a card's corner that takes the drag of its resize handle. The pointer over it is a double arrow that
/// turns as the pointer moves, so that it always points at the centre of the card's corner.
struct SpotHandleArea: View {
    let size: SpotSize
    @State private var angle = 45
    @MainActor private static var pointers: [Int: (image: Image, cursor: NSCursor)] = [:]

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard case .active(let point) = phase else { return }
                let next = SpotTokens.handleAngle(of: size, at: point)
                if next != angle { angle = next }
            }
            .pointerStyle(.image(Self.pointer(at: angle).image, hotSpot: .center))
    }

    /// The double arrow at this angle as the pointer of the app, for a drag, which no hover follows.
    static func cursor(at angle: Int) -> NSCursor {
        pointer(at: angle).cursor
    }

    /// A black double arrow with a white rim, as the system's resize arrows are, at this angle. It is drawn once for each
    /// angle.
    private static func pointer(at angle: Int) -> (image: Image, cursor: NSCursor) {
        if let pointer = pointers[angle] { return pointer }
        let side: CGFloat = 24
        let radians = CGFloat(angle) * .pi / 180
        let outline: [(CGFloat, CGFloat)] = [(-10, 0), (-4.5, -4.5), (-4.5, -1.2), (4.5, -1.2), (4.5, -4.5), (10, 0), (4.5, 4.5), (4.5, 1.2), (-4.5, 1.2), (-4.5, 4.5)]
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let path = NSBezierPath()
            for (index, (x, y)) in outline.enumerated() {
                let point = NSPoint(x: side / 2 + x * cos(radians) - y * sin(radians), y: side / 2 + x * sin(radians) + y * cos(radians))
                if index == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            path.close()
            path.lineJoinStyle = .round
            path.lineWidth = 2.5
            NSColor.white.setStroke()
            path.stroke()
            NSColor.black.setFill()
            path.fill()
            return true
        }
        let pointer = (image: Image(nsImage: image), cursor: NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2)))
        pointers[angle] = pointer
        return pointer
    }
}
