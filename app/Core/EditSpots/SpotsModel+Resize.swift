import Foundation

/// The resize of a card in Edit Spots by its grip.
extension SpotsModel {
    /// Resizes a card by its corner: it takes the size whose corner lies nearest the pointer, and the other cards make room.
    /// `grip` is where the person pressed the handle, in its square, and counts only when the resize starts.
    public func resizeSpot(_ id: String, by translation: CGSize, grip: CGPoint = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)) {
        guard isEditing, query.isEmpty, drag == nil else { return }
        if resize?.id != id {
            guard let index = visible.firstIndex(where: { $0.id == id }) else { return }
            resize = SpotResize(id: id, index: index, sizes: visible.map(\.size), choices: sizes(of: visible[index]), grid: grid)
            resizeGrip = grip
            scrollAtPress = gridScroll
            selected = index
        }
        pointerMove = translation
        guard let resize else { return }
        let target = resize.nearest(to: resize.corner(movedBy: inGrid(translation)))
        guard target != resize.size else { return }
        change(.edit) {
            self.resize?.size = target
            updateVisible()
        }
    }

    /// The size of the card that the person resizes.
    public var resizeSize: SpotSize? {
        resize?.size
    }

    /// Where the pointer that resizes a card lies in the handle's square on the card's corner as it is now.
    public var resizePointer: CGPoint? {
        guard let resize, let move = pointerMove, let rect = resize.placement(of: resize.size)?.rect else { return nil }
        let pointer = resize.corner(movedBy: inGrid(move))
        return CGPoint(x: pointer.x - rect.maxX + resizeGrip.x, y: pointer.y - rect.maxY + resizeGrip.y)
    }

    /// Ends the resize, and saves the size as the card's preferred size when it changed.
    public func dropResize() {
        guard let resize else { return }
        pointerMove = nil
        guard resize.size != resize.start else { return cancelResize() }
        arrangement.arrange(visible.map(\.id))
        arrangement.set(size: resize.size, of: resize.id)
        saveArrangement(selecting: resize.id) { self.resize = nil }
    }

    /// Puts the resized card and the cards that made room back as they were.
    public func cancelResize() {
        guard resize != nil else { return }
        pointerMove = nil
        change(.edit) {
            resize = nil
            updateVisible()
        }
    }
}
