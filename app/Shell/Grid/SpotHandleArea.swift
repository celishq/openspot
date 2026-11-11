import AppKit
import OpenspotCore
import SwiftUI

/// The square on a card's corner that takes the drag of its resize handle: the card snaps to the nearest size, and the
/// other cards make room. The pointer over it, and through its drag, is the system's bottom right resize arrow, with a
/// head on each side the card can still go. A release off the handle gives back the arrow.
struct SpotHandleArea: View {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let sizes: [SpotSize]
    /// Where the pointer lies in the square, which is where a press grips the handle.
    @State private var grip = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard case .active(let point) = phase else { return }
                grip = point
            }
            .pointerStyle(.image(Image(nsImage: Self.pointer(for: size.reach(among: sizes)).image), hotSpot: .center))
            .gesture(resize)
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged {
                model.resizeSpot(id, by: $0.translation, grip: grip)
                guard let size = model.resizeSize else { return }
                Self.pointer(for: size.reach(among: sizes)).set()
            }
            .onEnded { _ in
                let square = CGRect(x: 0, y: 0, width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
                let isOnHandle = model.resizePointer.map(square.contains) ?? false
                model.dropResize()
                if !isOnHandle { NSCursor.arrow.set() }
            }
    }

    /// The system's bottom right resize arrow, with grey heads on the sides that the card cannot go.
    private static func pointer(for reach: (grows: Bool, shrinks: Bool)) -> NSCursor {
        NSCursor.frameResize(position: .bottomRight, directions: reach.grows == reach.shrinks ? .all : reach.grows ? .outward : .inward)
    }
}
