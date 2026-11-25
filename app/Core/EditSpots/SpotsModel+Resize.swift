import Foundation

extension SpotsModel {
    public func resizeSpot(_ id: String, by translation: CGSize, grip: CGPoint = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)) {
        guard isEditing, query.isEmpty, drag == nil else { return }
        if resize?.id != id {
            guard let index = visible.firstIndex(where: { $0.id == id }) else { return }
            gesture = .size(SpotResize(id: id, index: index, placements: placements, choices: sizes(of: visible[index]), grid: columns.layout))
            resizeGrip = grip
            selected = index
        }
        pointerMove = translation
        guard var resize else { return }
        let target = resize.nearest(to: resize.corner(movedBy: translation))
        guard target != resize.size else { return }
        resize.size = target
        change(.edit) {
            gesture = .size(resize)
            updateVisible()
        }
    }

    public var resizeSize: SpotSize? {
        resize?.size
    }

    public var resizePointer: CGPoint? {
        guard let resize, let move = pointerMove, let rect = resize.placement(of: resize.size)?.rect else { return nil }
        let pointer = resize.corner(movedBy: move)
        return CGPoint(x: pointer.x - rect.maxX + resizeGrip.x, y: pointer.y - rect.maxY + resizeGrip.y)
    }

    public func dropResize() {
        asOnePress {
            guard let resize else { return }
            pointerMove = nil
            guard resize.size != resize.start else { return cancelResize() }
            saveLayout(resize.layout(of: resize.size), selecting: resize.id, ending: { gesture = nil }, landed: { self.endKeyEditing() })
        }
    }

    public func cancelResize() {
        guard resize != nil else { return }
        pointerMove = nil
        change(.edit) {
            gesture = nil
            updateVisible()
        }
        endKeyEditing()
    }
}
