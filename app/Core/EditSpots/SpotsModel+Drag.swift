import Foundation

extension SpotsModel {
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let entry = visible[start]
            let lifted = SpotDrag(id: id, index: start, placements: placements, grid: columns.layout, choices: sizes(of: entry))
            stopDragWait()
            tip = nil
            change(.edit) {
                drag = lifted
                carry = SpotCarry(entry: entry, size: lifted.start)
                selected = start
            }
        }
        pointerMove = translation
        guard let drag else { return }
        let moved = drag.capped(translation, within: windowInGrid)
        if lift.offset != moved { lift.offset = moved }
        let corner = inPanel(drag.homeRect.offsetBy(dx: moved.width, dy: moved.height).origin)
        if lift.origin != corner { lift.origin = corner }
        let target = drag.holds(movedBy: translation) ? drag.cell(movedBy: moved) : drag.home
        follow(target, of: drag)
    }

    private func follow(_ target: GridCell, of drag: SpotDrag) {
        guard target != drag.cell else { return stopDragWait() }
        guard target != dragTarget else { return }
        stopDragWait()
        dragTarget = target
        guard dragRest > .zero else { return land(at: target) }
        let rest = dragRest
        dragWait = Task { [weak self] in
            try? await Task.sleep(for: rest)
            guard !Task.isCancelled, let self, self.dragTarget == target else { return }
            self.land(at: target)
        }
    }

    public func dropSpot(by translation: CGSize) {
        asOnePress {
            guard let drag else { return }
            if host.isPointerOverWindow, let entry = visible.first(where: { $0.id == drag.id }), turnsOff(entry) {
                cancelDrag()
                return turnOff(entry.id)
            }
            let target = drag.holds(movedBy: translation) ? drag.cell(movedBy: drag.capped(translation, within: windowInGrid)) : drag.home
            guard let landed = drag.moved(to: target), target != drag.home else { return cancelDrag() }
            stopDragWait()
            pointerMove = nil
            saveLayout(landed.layout, selecting: drag.id, ending: {
                self.drag = nil
                landing = drag.id
            }, landed: { self.endLanding(of: drag.id) })
        }
    }

    public func cancelDrag() {
        guard let drag else { return }
        stopDragWait()
        pointerMove = nil
        change(.edit, {
            self.drag = nil
            landing = drag.id
            updateVisible()
            selected = drag.index
            carryHome()
        }, completion: { self.endLanding(of: drag.id) })
    }

    func carryHome() {
        guard let id = carry?.entry.id, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else { return }
        lift.origin = inPanel(placements[index].rect.origin)
        carry?.isLanding = true
    }

    private func endLanding(of id: String) {
        if landing == id { landing = nil }
        if drag == nil, carry?.entry.id == id { carry = nil }
        if drag == nil, lift.offset != .zero { lift.offset = .zero }
        endKeyEditing()
    }

    private var windowInGrid: CGRect {
        let origin = gridOrigin
        return windowInPanel.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private var windowInPanel: CGRect {
        columns.frame.insetBy(dx: SpotTokens.padding, dy: SpotTokens.padding)
    }

    private func inPanel(_ point: CGPoint) -> CGPoint {
        let origin = gridOrigin
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    private func land(at target: GridCell) {
        dragTarget = nil
        guard let next = drag?.moved(to: target) else { return }
        change(.edit) {
            drag = next
            updateVisible()
        }
    }

    func dropGesture() {
        stopDragWait()
        pointerMove = nil
        if drag != nil { drag = nil }
        if resize != nil { resize = nil }
        if carry != nil { carry = nil }
        if landing != nil { landing = nil }
        if lift.offset != .zero { lift.offset = .zero }
    }

    func stopDragWait() {
        dragWait?.cancel()
        dragWait = nil
        dragTarget = nil
    }

    public var gridOrigin: CGPoint {
        SpotTokens.gridOrigin(left: columns.leftExtent)
    }
}
