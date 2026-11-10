import AppKit
import OpenspotCore
import SwiftUI

/// The square on a card's corner that takes the drag of its resize handle: the card snaps to the nearest size, and the
/// other cards make room. The pointer over it, and through its drag, is a double arrow at the angle `handleAngle` gives.
/// A release off the handle gives back the arrow.
struct SpotHandleArea: View {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    @State private var angle = 45
    /// Where the pointer lies in the square, which is where a press grips the handle.
    @State private var grip = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)
    @MainActor private static var pointers: [Int: (image: Image, cursor: NSCursor)] = [:]

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard case .active(let point) = phase else { return }
                grip = point
                if let next = SpotTokens.handleAngle(of: size, at: point), next != angle { angle = next }
            }
            .pointerStyle(.image(Self.pointer(at: angle).image, hotSpot: .center))
            .gesture(resize)
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged {
                model.resizeSpot(id, by: $0.translation, grip: grip)
                guard let point = model.resizePointer, let resize = model.resize, let angle = SpotTokens.handleAngle(of: resize.size, at: point) else { return }
                Self.pointer(at: angle).cursor.set()
            }
            .onEnded { _ in
                let square = CGRect(x: 0, y: 0, width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
                let isOnHandle = model.resizePointer.map(square.contains) ?? false
                model.dropResize()
                if !isOnHandle { NSCursor.arrow.set() }
            }
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
