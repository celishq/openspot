import CoreGraphics
import Foundation

/// Lining up and spreading figures, and resizing a box.
extension Board {
    /// A way to line up figures: by an edge or a middle of the selection, or with equal gaps across or down.
    enum Arrangement: CaseIterable {
        case left, center, right, top, middle, bottom, spreadAcross, spreadDown
    }

    /// Lines up the boxes and strokes among these figures. Arrows follow the shapes that they hold.
    mutating func arrange(_ ids: Set<UUID>, _ arrangement: Arrangement) {
        let moving = figures.filter { ids.contains($0.id) && $0.kind != .arrow && $0.kind != .tie }
        guard moving.count > 1 else { return }
        let frames = Dictionary(uniqueKeysWithValues: moving.map { ($0.id, bounds(of: $0)) })
        let all = frames.values.reduce(CGRect.null) { $0.union($1) }
        var shifts: [UUID: CGPoint] = [:]
        switch arrangement {
        case .left: for (id, box) in frames { shifts[id] = CGPoint(x: all.minX - box.minX, y: 0) }
        case .center: for (id, box) in frames { shifts[id] = CGPoint(x: all.midX - box.midX, y: 0) }
        case .right: for (id, box) in frames { shifts[id] = CGPoint(x: all.maxX - box.maxX, y: 0) }
        case .top: for (id, box) in frames { shifts[id] = CGPoint(x: 0, y: all.minY - box.minY) }
        case .middle: for (id, box) in frames { shifts[id] = CGPoint(x: 0, y: all.midY - box.midY) }
        case .bottom: for (id, box) in frames { shifts[id] = CGPoint(x: 0, y: all.maxY - box.maxY) }
        case .spreadAcross, .spreadDown:
            let across = arrangement == .spreadAcross
            let order = frames.sorted { across ? $0.value.minX < $1.value.minX : $0.value.minY < $1.value.minY }
            let room = across ? all.width : all.height
            let taken = order.reduce(0) { $0 + (across ? $1.value.width : $1.value.height) }
            let gap = (room - taken) / CGFloat(order.count - 1)
            var next = across ? all.minX : all.minY
            for (id, box) in order {
                shifts[id] = across ? CGPoint(x: next - box.minX, y: 0) : CGPoint(x: 0, y: next - box.minY)
                next += (across ? box.width : box.height) + gap
            }
        }
        for (id, shift) in shifts where shift != .zero {
            move([id], by: shift)
        }
    }

    /// Gives a box a new frame. An image keeps its proportions, and takes its height from the new width.
    mutating func resize(_ id: UUID, to frame: CGRect) {
        update(id) { figure in
            var frame = frame.standardized
            if figure.kind == .image, figure.frame.width > 0 {
                frame.size.height = frame.width * figure.frame.height / figure.frame.width
            }
            figure.points = [frame.origin, CGPoint(x: frame.maxX, y: frame.maxY)]
        }
    }
}
