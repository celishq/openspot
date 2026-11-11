import AppKit
import OpenspotCore
import SwiftUI

/// The square on a card's corner that takes the drag of its resize handle: the card snaps to the nearest size, and the
/// other cards make room. The pointer over it, and through its drag, is the system's resize arrow at the angle
/// `handleAngle` gives, with a head on each side the card can still go. A release off the handle gives back the arrow.
struct SpotHandleArea: View {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let sizes: [SpotSize]
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
            .pointerStyle(.image(Self.pointer(at: angle, reach: size.reach(among: sizes)).image, hotSpot: .center))
            .gesture(resize)
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged {
                model.resizeSpot(id, by: $0.translation, grip: grip)
                guard let point = model.resizePointer, let size = model.resizeSize, let angle = SpotTokens.handleAngle(of: size, at: point) else { return }
                Self.pointer(at: angle, reach: size.reach(among: sizes)).cursor.set()
            }
            .onEnded { _ in
                let square = CGRect(x: 0, y: 0, width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
                let isOnHandle = model.resizePointer.map(square.contains) ?? false
                model.dropResize()
                if !isOnHandle { NSCursor.arrow.set() }
            }
    }

    /// The system's left and right resize arrow turned to this angle, with grey heads on the sides that the card cannot go.
    /// It is drawn once for each angle and reach.
    private static func pointer(at angle: Int, reach: (grows: Bool, shrinks: Bool)) -> (image: Image, cursor: NSCursor) {
        let directions: NSCursor.FrameResizeDirection.Set = reach.grows == reach.shrinks ? .all : reach.grows ? .outward : .inward
        let key = angle * 4 + (reach.grows == reach.shrinks ? 0 : reach.grows ? 1 : 2)
        if let pointer = pointers[key] { return pointer }
        let arrow = NSCursor.frameResize(position: .right, directions: directions).image
        let side = (hypot(arrow.size.width, arrow.size.height)).rounded(.up)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let turn = NSAffineTransform()
            turn.translateX(by: side / 2, yBy: side / 2)
            turn.rotate(byDegrees: CGFloat(angle))
            turn.concat()
            let rect = NSRect(x: -arrow.size.width / 2, y: -arrow.size.height / 2, width: arrow.size.width, height: arrow.size.height)
            arrow.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            return true
        }
        let pointer = (image: Image(nsImage: image), cursor: NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2)))
        pointers[key] = pointer
        return pointer
    }
}
