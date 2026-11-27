import Foundation

extension SpotsModel {
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let entry = visible[start]
            let lifted = SpotDrag(id: id, index: start, placements: placements, grid: grid, choices: sizes(of: entry))
            stopDragWait()
            tip = nil
            change(.edit) {
                gesture = .move(lifted)
                carry = SpotCarry(entry: entry, size: lifted.start)
                selected = start
            }
        }
        pointerMove = translation
        guard let drag else { return }
        let moved = drag.capped(translation, within: isArranging ? .infinite : windowInGrid)
        if lift.offset != moved { lift.offset = moved }
        let corner = inPanel(drag.homeRect.offsetBy(dx: moved.width, dy: moved.height).origin)
        if lift.origin != corner { lift.origin = corner }
        let target = drag.holds(movedBy: translation) ? drag.cell(movedBy: moved) : drag.home
        follow(target, of: drag)
    }

    private func follow(_ target: GridCell, of drag: SpotDrag) {
        guard target != drag.cell else { return stopDragWait() }
        afterRest(at: target) { self.land(at: target) }
    }

    func afterRest(at cell: GridCell, _ land: @escaping @MainActor () -> Void) {
        guard cell != dragTarget else { return }
        stopDragWait()
        guard dragRest > .zero else { return land() }
        dragTarget = cell
        let rest = dragRest
        dragWait = Task { [weak self] in
            try? await Task.sleep(for: rest)
            guard !Task.isCancelled, let self, self.dragTarget == cell else { return }
            self.dragWait = nil
            self.dragTarget = nil
            land()
        }
    }

    public func dropSpot(by translation: CGSize) {
        asOnePress {
            guard let drag else { return }
            let isOut = host.isPointerOverWindow || (isArranging && !drag.holds(movedBy: translation))
            if isOut, let entry = visible.first(where: { $0.id == drag.id }), takesOffGrid(entry) {
                let corner = SpotTokens.gridOrigin(scrollOffset: gridScroll)
                let slot = shelf.slot(at: CGPoint(x: corner.x + drag.homeRect.minX + translation.width, y: corner.y + drag.homeRect.minY + translation.height), size: entry.size)
                stopDragWait()
                pointerMove = nil
                gesture = nil
                if landing != nil { landing = nil }
                return takeOffGrid(entry.id, to: slot)
            }
            let target = drag.holds(movedBy: translation) ? drag.cell(movedBy: drag.capped(translation, within: windowInGrid)) : drag.home
            guard let landed = drag.moved(to: target), target != drag.home else { return cancelDrag() }
            stopDragWait()
            pointerMove = nil
            saveLayout(landed.layout, selecting: drag.id, ending: {
                gesture = nil
                landing = drag.id
            }, landed: { self.endLanding(of: drag.id) })
        }
    }

    public func cancelDrag() {
        guard let drag else { return }
        stopDragWait()
        pointerMove = nil
        change(.edit, {
            gesture = nil
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

    func carryToShelf() {
        guard let id = carry?.entry.id, let origin = shelf.origin(of: id) else { return }
        lift.origin = origin
        if let size = shelf.size(of: id), carry?.size != size { carry?.size = size }
        carry?.isLanding = true
        landing = id
    }

    func endLanding(of id: String) {
        if landing == id { landing = nil }
        if drag == nil, carry?.entry.id == id { carry = nil }
        if drag == nil, lift.offset != .zero { lift.offset = .zero }
        endKeyEditing()
    }

    private var windowInGrid: CGRect {
        let origin = SpotTokens.gridOrigin()
        return windowInPanel.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    private var windowInPanel: CGRect {
        SpotTokens.panelFrame.insetBy(dx: SpotTokens.padding, dy: SpotTokens.padding)
    }

    private func inPanel(_ point: CGPoint) -> CGPoint {
        let origin = SpotTokens.gridOrigin()
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    private func land(at target: GridCell) {
        dragTarget = nil
        guard let next = drag?.moved(to: target) else { return }
        change(.edit) {
            gesture = .move(next)
            updateVisible()
        }
    }

    public func gridScrolled(to offset: CGFloat) {
        guard gridScroll != offset else { return }
        gridScroll = offset
        if tip != nil { tip = nil }
    }

    func dropGesture() {
        stopDragWait()
        pointerMove = nil
        if gesture != nil { gesture = nil }
        if carry != nil { carry = nil }
        if landing != nil { landing = nil }
        if lift.offset != .zero { lift.offset = .zero }
    }

    func stopDragWait() {
        dragWait?.cancel()
        dragWait = nil
        dragTarget = nil
    }
}
