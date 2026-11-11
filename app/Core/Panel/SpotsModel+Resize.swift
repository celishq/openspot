import Foundation

/// The resize of a card in Edit Spots by its grip.
extension SpotsModel {
    /// Resizes a card by its corner: it takes the size whose corner lies nearest the pointer, and the other cards make room.
    /// `grip` is where the person pressed the handle, in its square, and counts only when the resize starts.
    public func resizeSpot(_ id: String, by translation: CGSize, grip: CGPoint = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)) {
        guard isEditing, query.isEmpty, drag == nil else { return }
        if dock.items.contains(where: { $0.id == id }) { return resizeTile(id, by: translation, grip: grip) }
        if resize?.id != id {
            guard let index = visible.firstIndex(where: { $0.id == id }) else { return }
            resize = SpotResize(id: id, index: index, sizes: visible.map(\.size), choices: sizes(of: visible[index]))
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

    /// Resizes a spot of the dock by its corner: it takes the size, among its sizes, whose corner lies nearest the pointer,
    /// and the dock lays out again.
    private func resizeTile(_ id: String, by translation: CGSize, grip: CGPoint) {
        guard carry == nil else { return }
        if dockResize?.id != id {
            guard let index = dock.shown.firstIndex(where: { $0.id == id }) else { return }
            dockResize = (id, dock.shown[index].size, dock.rects(columns: dockColumns)[index].origin)
            resizeGrip = grip
        }
        pointerMove = translation
        guard let tile = dockResize, let item = dock.items.first(where: { $0.id == id }) else { return }
        let corner = tileCorner(of: tile, movedBy: translation)
        let reach = { (size: SpotSize) in
            hypot(tile.origin.x + SpotTokens.width(columns: min(size.columns, self.dockColumns)) - corner.x, tile.origin.y + SpotTokens.height(rows: size.rows) - corner.y)
        }
        guard let target = sizes(of: Entry(spot: item.spot, run: nil)).min(by: { reach($0) < reach($1) }), target != item.size else { return }
        change(.edit) { dock = dock.resized(id, to: target) }
    }

    /// Where the corner of a resized spot of the dock lies, in the dock's rows, when the pointer has moved this far.
    private func tileCorner(of tile: (id: String, start: SpotSize, origin: CGPoint), movedBy translation: CGSize) -> CGPoint {
        CGPoint(
            x: tile.origin.x + SpotTokens.width(columns: min(tile.start.columns, dockColumns)) + translation.width,
            y: tile.origin.y + SpotTokens.height(rows: tile.start.rows) + translation.height
        )
    }

    /// The size of the card that the person resizes, in the grid or in the dock.
    public var resizeSize: SpotSize? {
        if let tile = dockResize { return dock.items.first { $0.id == tile.id }?.size }
        return resize?.size
    }

    /// Where the pointer that resizes a card lies in the handle's square on the card's corner as it is now.
    public var resizePointer: CGPoint? {
        if let tile = dockResize {
            guard let move = pointerMove, let index = dock.shown.firstIndex(where: { $0.id == tile.id }) else { return nil }
            let rect = dock.rects(columns: dockColumns)[index]
            let corner = tileCorner(of: tile, movedBy: move)
            return CGPoint(x: corner.x - rect.maxX + resizeGrip.x, y: corner.y - rect.maxY + resizeGrip.y)
        }
        guard let resize, let move = pointerMove, let rect = resize.placement(of: resize.size)?.rect else { return nil }
        let pointer = resize.corner(movedBy: inGrid(move))
        return CGPoint(x: pointer.x - rect.maxX + resizeGrip.x, y: pointer.y - rect.maxY + resizeGrip.y)
    }

    /// Ends the resize, and saves the size as the card's preferred size when it changed.
    public func dropResize() {
        if let tile = dockResize { return keepSize(of: tile.id, from: tile.start) }
        guard let resize else { return }
        pointerMove = nil
        guard resize.size != resize.start else { return cancelResize() }
        arrangement.arrange(visible.map(\.id))
        arrangement.set(size: resize.size, of: resize.id)
        saveArrangement(selecting: resize.id) { self.resize = nil }
    }

    /// Keeps the size of a resized spot of the dock as its preferred size when it changed.
    private func keepSize(of id: String, from start: SpotSize) {
        pointerMove = nil
        guard let size = dock.items.first(where: { $0.id == id })?.size, size != start else { return cancelResize() }
        dockResize = nil
        arrangement.set(size: size, of: id)
        do {
            try files.config.write(arrangement)
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
    }

    /// Puts the resized card and the cards that made room back as they were.
    public func cancelResize() {
        if let tile = dockResize {
            pointerMove = nil
            dockResize = nil
            return change(.edit) { dock = dock.resized(tile.id, to: tile.start) }
        }
        guard resize != nil else { return }
        pointerMove = nil
        change(.edit) {
            resize = nil
            updateVisible()
        }
    }
}
