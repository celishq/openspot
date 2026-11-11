import Foundation
import Observation

/// Edit Spots: the order, the size, the letter and the place on the grid of each spot.
extension SpotsModel {
    /// The code of the Delete key, which takes away the letter that records.
    private static let deleteCode: UInt32 = 51

    /// The sizes that a person can prefer for a spot, in words for its menu.
    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? entry.command.sizes : []
    }

    /// Starts Edit Spots on the grid, with the search cleared.
    public func beginEditing() {
        guard openList == nil else { return }
        closeMenu()
        let folder = files.folder
        change(.edit) {
            query = ""
            isEditing = true
            updateVisible()
            refreshDock(in: folder)
        }
    }

    /// Shows the spots of the dock whose name holds this text.
    public func searchDock(_ text: String) {
        dock.query = text
    }

    /// Takes whether the person types in the dock's search.
    public func searchesDock(_ isOn: Bool) {
        if isSearchingDock != isOn { isSearchingDock = isOn }
    }

    /// Makes the dock from the spots of this folder that are off, and keeps its search.
    func refreshDock(in folder: PluginFolder) {
        let choice = arrangement
        var next = SpotDock(items: Self.offSpots(in: folder).map { SpotDock.Item(command: $0.command, isOwn: $0.isOwn, size: choice.size(of: $0.id)) })
        next.query = dock.query
        if next != dock { dock = next }
    }

    /// The core spots of this folder that are not on, and the spots of its files that the person turned off. A sheet that
    /// another spot opens is not one.
    private static func offSpots(in folder: PluginFolder) -> [SpotDock.Item] {
        let own = (try? PluginFolder(url: folder.url).keptScan())?.plugins ?? []
        let ownIDs = Set(own.map(\.id))
        let core = folder.keptCoreChoices()
            .filter { !folder.enabled.contains(PluginFolder.coreID(of: $0)) && !ownIDs.contains(PluginFolder.coreID(of: $0)) }
        let turnedOff = own.filter { folder.disabled.contains($0.id) }.flatMap(\.commands)
        let opened = Set(turnedOff.compactMap(\.opens))
        return core.map { SpotDock.Item(command: $0) } + turnedOff.filter { !opened.contains($0.id) }.map { SpotDock.Item(command: $0, isOwn: true) }
    }

    /// Whether the minus of Edit Spots can turn this spot off. A built-in and a card of faults stay on.
    public func turnsOff(_ entry: Entry) -> Bool {
        entry.item == nil && entry.command.host == nil && !entry.command.isBuiltIn && entry.command.fault == nil
    }

    /// Turns a spot off from Edit Spots: its card leaves the panel, and the dock shows it.
    public func turnOff(_ id: String) {
        guard let entry = visible.first(where: { $0.id == id }), turnsOff(entry) else { return }
        turn(entry.command, on: false)
    }

    /// Turns a spot of the dock on: its card takes a place in the panel.
    public func turnOn(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }) else { return }
        turn(item.command, on: true)
    }

    /// Moves the file of a spot of the dock to the Trash, as Delete does in the action menu, so `⌘Z` puts it back.
    public func delete(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        remove(Entry(command: item.command, run: nil))
    }

    /// Turns a spot on or off in the config, and loads the spots again on the edit motion, after `ending` runs in it.
    @discardableResult
    private func turn(_ command: Spot, on isOn: Bool, ending: () -> Void = {}) -> Bool {
        do {
            try files.config.turn(files.folder.fileID(of: command), on: isOn)
        } catch {
            host.notify("\(command.name) was not turned \(isOn ? "on" : "off"). \(Self.reason(error))")
            return false
        }
        change(.edit) {
            ending()
            reload()
        }
        return true
    }

    /// Ends Edit Spots. A panel that closes passes no motion, so that nothing moves during its fade.
    public func endEditing(moving: Bool = true) {
        guard isEditing else { return }
        stopDragWait()
        change(moving ? .edit : nil) {
            isEditing = false
            drag = nil
            landing = nil
            carry = nil
            arrival = nil
            dockResize = nil
            resize = nil
            pointerMove = nil
            if lift.offset != .zero { lift.offset = .zero }
            selected = 0
            isSearchingDock = false
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
        if isSearchingDock {
            searchDock("")
            isSearchingDock = false
            return
        }
        if drag != nil || resize != nil || carry != nil || dockResize != nil {
            if key.name == "escape" {
                cancelDrag()
                cancelResize()
            }
            return
        }
        if openSheet(on: key) { return }
        let order = visible.map(\.id)
        switch (key.name, key.isShift) {
        case ("escape", _): endEditing()
        case ("left", false): moveSelection(dx: -1, dy: 0)
        case ("right", false): moveSelection(dx: 1, dy: 0)
        case ("up", false): moveSelection(dx: 0, dy: -1)
        case ("down", false): moveSelection(dx: 0, dy: 1)
        case ("left", true), ("up", true): moveSelectedSpot(by: -1, in: order)
        case ("right", true), ("down", true): moveSelectedSpot(by: 1, in: order)
        case ("s", _): stepSelectedSize()
        case ("h", _): toggleSelectedOnGrid()
        case ("l", _): if let entry = selectedEntry, entry.item == nil { toggleRecording(id: entry.id) }
        default: break
        }
    }

    /// Moves the card that the person drags, inside the panel's window, and lifts it when the drag starts. The window
    /// carries it over the panel and the dock. The other cards make room where a release would put it once the pointer has
    /// rested there for `dragRest`, and go back to their places while the pointer is off the grid. A card on the grid lands
    /// among the cards on the grid, and a hidden card among the hidden cards.
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil, carry?.tile == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let onGrid = visible.filter(\.isOnGrid).count
            let places = visible[start].isOnGrid ? 0...(onGrid - 1) : onGrid...(visible.count - 1)
            let lifted = SpotDrag(id: id, start: start, sizes: visible.map(\.size), places: places)
            let entry = visible[start]
            stopDragWait()
            scrollAtPress = gridScroll
            change(.edit) {
                drag = lifted
                carry = SpotCarry(entry: entry, size: lifted.placement(at: start)?.size ?? entry.size, turnsOff: turnsOff(entry))
                selected = start
            }
        }
        pointerMove = translation
        guard let drag else { return }
        let move = inGrid(translation)
        let moved = drag.capped(move, within: windowInGrid)
        if lift.offset != moved { lift.offset = moved }
        let corner = inPanel(drag.rect(at: drag.start).offsetBy(dx: moved.width, dy: moved.height).origin)
        if lift.origin != corner { lift.origin = corner }
        let centre = drag.centre(movedBy: move)
        let isOverDock = dockInGrid?.contains(centre) == true
        if carry?.isOverDock != isOverDock { carry?.isOverDock = isOverDock }
        let target = !isOverDock && drag.holds(centre) ? drag.nearest(to: drag.centre(movedBy: moved)) : drag.start
        follow(target, of: drag)
    }

    /// Makes room at this place once the pointer has rested near it for `dragRest`.
    private func follow(_ target: Int, of drag: SpotDrag) {
        guard target != drag.place else { return stopDragWait() }
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

    /// Ends the drag: the card lands at the place nearest the lifted card, and the order is saved. A release on the dock
    /// turns the spot off when it can be off. A release with the pointer off the grid, or where the card started, puts every
    /// card back.
    public func dropSpot(by translation: CGSize) {
        guard let drag else { return }
        let move = inGrid(translation)
        let centre = drag.centre(movedBy: move)
        if dockInGrid?.contains(centre) == true {
            guard carry?.turnsOff == true, let entry = visible.first(where: { $0.id == drag.id }) else { return cancelDrag() }
            return turnOffDropped(entry)
        }
        let place = drag.nearest(to: drag.centre(movedBy: drag.capped(move, within: windowInGrid)))
        guard drag.holds(centre), place != drag.start else { return cancelDrag() }
        stopDragWait()
        pointerMove = nil
        var order = dragged(cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.removeAll { $0 == drag.id }
        order.insert(drag.id, at: place)
        arrangement.arrange(order)
        saveArrangement(selecting: drag.id, ending: {
            self.drag = nil
            landing = drag.id
        }, landed: { self.endLanding(of: drag.id) })
    }

    /// Moves a spot of the dock that the person drags, and lifts its card out of the dock when the drag starts. While the
    /// card lies over the grid, it takes the size it has there, and the other cards make room where a release would turn
    /// it on once the pointer has rested there for `dragRest`.
    public func dragDockSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil, dockResize == nil else { return }
        if carry?.entry.id != id {
            guard carry == nil, drag == nil, let item = dock.shown.first(where: { $0.id == id }), let tile = tileRect(of: id) else { return }
            let entry = Entry(command: item.command, run: nil, choice: arrangement)
            let start = visible.filter(\.isOnGrid).count
            var sizes = visible.map(\.size)
            sizes.insert(entry.size, at: start)
            arrival = SpotDrag(id: id, start: start, sizes: sizes, places: 0...start)
            stopDragWait()
            lift.origin = tile.origin
            change(.edit) { carry = SpotCarry(entry: entry, size: item.size, turnsOff: false, tile: tile) }
        }
        pointerMove = translation
        guard let carry, let tile = carry.tile, var arrival else { return }
        let centre = CGPoint(x: tile.midX + translation.width, y: tile.midY + translation.height)
        let grid = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        let point = CGPoint(x: centre.x - grid.x, y: centre.y - grid.y)
        let panel = CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        let isOverGrid = panel.contains(centre) && dockFrame?.contains(centre) != true && arrival.holds(point)
        let size = isOverGrid ? arrival.placement(at: arrival.start)?.size ?? carry.entry.size : dock.items.first { $0.id == id }?.size ?? carry.size
        if carry.size != size { self.carry?.size = size }
        let card = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let origin = held(CGRect(x: centre.x - card.width / 2, y: centre.y - card.height / 2, width: card.width, height: card.height))
        if lift.origin != origin { lift.origin = origin }
        guard isOverGrid else {
            guard drag != nil else { return }
            stopDragWait()
            return change(.edit) {
                drag = nil
                updateVisible()
            }
        }
        let start = arrival.rect(at: arrival.start)
        let offset = CGSize(width: origin.x - grid.x - start.minX, height: origin.y - grid.y - start.minY)
        if lift.offset != offset { lift.offset = offset }
        let target = arrival.nearest(to: arrival.centre(movedBy: offset))
        guard let drag else {
            arrival.place = target
            return change(.edit) {
                drag = arrival
                updateVisible()
            }
        }
        follow(target, of: drag)
    }

    /// Ends the drag of a spot of the dock: over the grid it turns on at the place nearest its card, and anywhere else it
    /// goes back to the dock.
    public func dropDockSpot(by translation: CGSize) {
        guard let carry, carry.tile != nil else { return }
        dragDockSpot(carry.entry.id, by: translation)
        guard let drag, drag.id == carry.entry.id else { return sendBack() }
        turnOnDropped(carry.entry, at: drag.nearest(to: drag.centre(movedBy: lift.offset)))
    }

    /// Turns on a spot of the dock that the person dropped on the grid, at this place, and lands its card there.
    private func turnOnDropped(_ entry: Entry, at place: Int) {
        stopDragWait()
        pointerMove = nil
        arrival = nil
        var order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.insert(entry.id, at: min(place, order.count))
        var next = arrangement
        next.arrange(order)
        next.set(isEnabled: true, of: files.folder.fileID(of: entry.command))
        do {
            try files.config.write(next)
        } catch {
            host.notify("\(entry.command.name) was not turned on. \(Self.reason(error))")
            return sendBack()
        }
        change(.edit, {
            drag = nil
            landing = entry.id
            reload()
            if let index = visible.firstIndex(where: { $0.id == entry.id }) { selected = index }
            carryHome()
        }, completion: { self.endLanding(of: entry.id) })
    }

    /// Puts a carried spot of the dock back: its card leaves the grid, and glides back to its tile.
    private func sendBack() {
        guard let carry, let tile = carry.tile else { return }
        let id = carry.entry.id
        stopDragWait()
        pointerMove = nil
        arrival = nil
        if let size = dock.items.first(where: { $0.id == id })?.size, size != carry.size { self.carry?.size = size }
        let home = tileRect(of: id) ?? tile
        change(.edit, {
            drag = nil
            updateVisible()
            lift.origin = home.origin
            self.carry?.isLanding = true
        }, completion: { self.endLanding(of: id) })
    }

    /// Where the card of a spot of the dock lies in the panel's space, as the dock shows it now.
    private func tileRect(of id: String) -> CGRect? {
        guard let dockFrame, let index = dock.shown.firstIndex(where: { $0.id == id }) else { return nil }
        let rect = dock.rects(columns: SpotTokens.dockColumns(width: dockFrame.width))[index]
        return rect.offsetBy(dx: dockFrame.minX + SpotTokens.padding, dy: dockFrame.minY + SpotTokens.dockRowsTop - dockScroll)
    }

    /// Takes how far the dock has scrolled.
    public func dockScrolled(to offset: CGFloat) {
        dockScroll = offset
    }

    /// Puts the dragged card and the cards that made room back where they were. A spot of the dock goes back to the dock.
    public func cancelDrag() {
        if carry?.tile != nil { return sendBack() }
        guard let drag else { return }
        stopDragWait()
        pointerMove = nil
        change(.edit, {
            self.drag = nil
            landing = drag.id
            updateVisible()
            selected = drag.start
            carryHome()
        }, completion: { self.endLanding(of: drag.id) })
    }

    /// Turns off the spot of a card that the person dropped on the dock: the card fades where it lies, and the other cards
    /// close the gap. A spot that cannot be turned off goes back.
    private func turnOffDropped(_ entry: Entry) {
        stopDragWait()
        pointerMove = nil
        let isOff = turn(entry.command, on: false) {
            drag = nil
            carry = nil
        }
        guard isOff else { return cancelDrag() }
        if lift.offset != .zero { lift.offset = .zero }
    }

    /// Moves the carried card to the place of its card on the grid, where it lands, and off the dock.
    private func carryHome() {
        guard let id = carry?.entry.id, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else { return }
        lift.origin = inPanel(placements[index].rect.origin)
        carry?.isOverDock = false
        carry?.isLanding = true
    }

    /// Ends the landing of a card, and clears the pointer's move, which no card reads once the drag ends, and the carried
    /// card. The move stays through the landing, because a change of it there would move the card ahead of the landing's
    /// motion.
    private func endLanding(of id: String) {
        if landing == id { landing = nil }
        if drag == nil, carry?.entry.id == id { carry = nil }
        if drag == nil, lift.offset != .zero { lift.offset = .zero }
    }

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
        guard let target = sizes(of: Entry(command: item.command, run: nil)).min(by: { reach($0) < reach($1) }), target != item.size else { return }
        change(.edit) { dock = dock.resized(id, to: target) }
    }

    /// Where the corner of a resized spot of the dock lies, in the dock's rows, when the pointer has moved this far.
    private func tileCorner(of tile: (id: String, start: SpotSize, origin: CGPoint), movedBy translation: CGSize) -> CGPoint {
        CGPoint(
            x: tile.origin.x + SpotTokens.width(columns: min(tile.start.columns, dockColumns)) + translation.width,
            y: tile.origin.y + SpotTokens.height(rows: tile.start.rows) + translation.height
        )
    }

    /// How many columns the dock's rows hold.
    private var dockColumns: Int {
        SpotTokens.dockColumns(width: dockFrame?.width ?? SpotTokens.dockWidth)
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

    /// Takes how far the grid has scrolled. A card that the person drags or resizes moves with the grid, as if the pointer
    /// moved as far.
    public func gridScrolled(to offset: CGFloat) {
        guard gridScroll != offset else { return }
        gridScroll = offset
        guard let move = pointerMove else { return }
        if let carry, carry.tile != nil {
            dragDockSpot(carry.entry.id, by: move)
        } else if let drag {
            dragSpot(drag.id, by: move)
        } else if let resize {
            resizeSpot(resize.id, by: move)
        }
    }

    /// The pointer's move as a move over the grid, with the scroll since the press added.
    private func inGrid(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width, height: translation.height + gridScroll - scrollAtPress)
    }

    /// The panel's window in the grid's places, a padding inside its edges, where a lifted card stays. In Edit Spots it
    /// holds the dock too.
    private var windowInGrid: CGRect {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return windowInPanel.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// The panel's window in the panel's space, a padding inside its edges. In Edit Spots it holds the dock too.
    private var windowInPanel: CGRect {
        let panel = CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        return panel.union(dockFrame ?? panel).insetBy(dx: SpotTokens.padding, dy: SpotTokens.padding)
    }

    /// The top left corner that keeps this card inside the window, nearest to its own.
    private func held(_ card: CGRect) -> CGPoint {
        let window = windowInPanel
        return CGPoint(x: min(max(card.minX, window.minX), window.maxX - card.width), y: min(max(card.minY, window.minY), window.maxY - card.height))
    }

    /// The dock in the grid's places.
    private var dockInGrid: CGRect? {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return dockFrame?.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// A point of the grid in the panel's space.
    private func inPanel(_ point: CGPoint) -> CGPoint {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    /// These cards with the dragged card moved to its place.
    func dragged(_ list: [Entry]) -> [Entry] {
        guard let drag, let from = list.firstIndex(where: { $0.id == drag.id }) else { return list }
        var list = list
        let entry = list.remove(at: from)
        list.insert(entry, at: min(drag.place, list.count))
        return list
    }

    private func land(at place: Int) {
        dragTarget = nil
        change(.edit) {
            drag?.place = place
            updateVisible()
            selected = place
        }
    }

    private func stopDragWait() {
        dragWait?.cancel()
        dragWait = nil
        dragTarget = nil
    }

    private func moveSelectedSpot(by step: Int, in order: [String]) {
        guard order.indices.contains(selected),
              let place = SpotGrid().nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
        moveSpot(order[selected], to: place)
    }

    /// Puts a spot at this place in the grid, and keeps it selected.
    public func moveSpot(_ id: String, to place: Int) {
        var order = visible.map(\.id)
        guard let from = order.firstIndex(of: id), order.indices.contains(place), place != from else { return }
        order.remove(at: from)
        order.insert(id, at: place)
        arrangement.arrange(order)
        saveArrangement(selecting: id)
    }

    private func stepSelectedSize() {
        guard let entry = selectedEntry else { return }
        let sizes = visible.map(\.size)
        if let next = SpotGrid().nextSize(of: selected, in: sizes, among: self.sizes(of: entry)) { prefer(next, for: entry.id) }
    }

    private func toggleSelectedOnGrid() {
        guard let entry = selectedEntry else { return }
        setOnGrid(!entry.isOnGrid, for: entry.id)
    }

    /// Takes a preferred size for a spot. The grid can still change it to fill a row.
    public func prefer(_ size: SpotSize, for id: String) {
        arrangement.arrange(visible.map(\.id))
        arrangement.set(size: size, of: id)
        saveArrangement(selecting: id)
    }

    public func setOnGrid(_ isOn: Bool, for id: String) {
        arrangement.arrange((cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id))
        arrangement.set(isOnGrid: isOn, of: id)
        saveArrangement(selecting: id)
    }

    /// Takes the letter for the spot that records: a letter or a digit with no modifier gives it, and Delete takes its letter
    /// away. A letter that another spot held moves, and a toast names that spot. Any other key leaves it recording, and says
    /// why.
    func recordLetter(code: UInt32, modifiers: Shortcut.Modifiers) {
        guard let id = recording else { return }
        let letter = CommandKey(code: code)
        guard code == Self.deleteCode || (letter != nil && modifiers.isEmpty) else {
            host.notify("Press a letter or a digit with no other key, or Delete to take the letter away.")
            return
        }
        stopRecording()
        arrangement.arrange(visible.map(\.id))
        let holder = arrangement.give(code == Self.deleteCode ? nil : letter, to: id, over: defaultArrangement)
        if let holder, let letter {
            let name = { (spot: String) in self.entries.first { $0.id == spot }?.command.name ?? spot }
            host.notify("\(letter.name.uppercased()) now runs \(name(id)), so \(name(holder)) has no letter.")
        }
        saveArrangement(selecting: id)
    }

    /// Writes the arrangement, and lays out the cards from it on the edit motion, after `ending` runs in that motion.
    /// `landed` runs when the motion ends.
    private func saveArrangement(selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        do {
            try files.config.write(arrangement)
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
        change(.edit, {
            ending()
            rebuildEntries()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
            carryHome()
        }, completion: landed)
    }
}
