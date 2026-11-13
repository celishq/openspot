import Foundation
import Observation

/// Edit Spots: the order, the size, the letter and the place on the grid of each spot.
extension SpotsModel {
    /// The code of the Delete key, which takes away the letter that records.
    private static let deleteCode: UInt32 = 51

    /// The sizes that a person can prefer for a spot, in words for its menu.
    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? entry.spot.sizes : []
    }

    /// Starts Edit Spots on the grid, with the search cleared.
    public func beginEditing() {
        guard openList == nil else { return }
        closeMenu()
        let folder = self.folder
        change(.edit) {
            query = ""
            isEditing = true
            updateVisible()
            if dockStamp == folder.stamp() { composeDock() } else { refreshDock(in: folder) }
        }
    }

    /// Shows the panel in Edit Spots with the store, from the grid, a search or a sheet.
    public func openStore() {
        if openList != nil { closeList(moving: false) }
        host.show()
        beginEditing()
    }

    /// Shows the spots of the dock whose name holds this text, and closes the listing when the text changes.
    public func searchDock(_ text: String) {
        guard text != dock.query else { return }
        dock.opened = nil
        dock.isSheetOut = false
        dock.query = text
    }

    /// Shows the spots of this section of the store, and closes the listing.
    public func showStoreSection(_ section: SpotDock.Section) {
        guard section != dock.section else { return }
        change(.edit) {
            dock.opened = nil
            dock.isSheetOut = false
            dock.section = section
        }
    }

    /// Takes the next step of a spot of the store: opens it, adds it, puts it on the grid, or publishes it.
    public func takeStep(of id: String) {
        guard let item = dock.items.first(where: { $0.id == id }) else { return }
        switch item.step {
        case .open: choose(.open, for: id)
        case .add: setState(.searchOnly, of: id)
        case .addToGrid: setState(.onGrid, of: id)
        case .publish: choose(.publish, for: id)
        }
    }

    /// Does a choice of the menu of a spot of the store.
    public func choose(_ action: SpotDock.Action, for id: String) {
        guard let item = dock.items.first(where: { $0.id == id }) else { return }
        switch action {
        case .place(let state): setState(state, of: id)
        case .open:
            endEditing()
            press(id)
        case .publish: Task { await publish(id) }
        case .share: sharePackage(id)
        case .copyPrompt: copyListingPrompt(id)
        case .edit: edit(Entry(spot: item.spot, run: nil))
        case .moveToTrash: delete(id)
        }
    }

    /// Opens the listing of a spot of the store in a sheet under its line, or closes it when it is open. A new sheet is built
    /// closed and grows on the next turn; an open sheet moves to the line of another spot.
    public func openListing(_ id: String) {
        guard let item = dock.shown.first(where: { $0.id == id }) else { return }
        tip = nil
        guard dock.opened != id else { return closeListing() }
        dockListing = SpotListing(beside: item.spot)
        guard !dock.isSheetOut else { return change(.edit) { dock.opened = id } }
        dock.opened = id
        Task { @MainActor [weak self] in
            guard let self, self.dock.opened == id, !self.dock.isSheetOut else { return }
            self.change(.edit) { self.dock.isSheetOut = true }
        }
    }

    /// Closes the sheet of the opened spot back under its line, and drops it when it is in.
    private func closeListing() {
        change(.edit, { dock.isSheetOut = false }, completion: {
            if !self.dock.isSheetOut { self.dock.opened = nil }
        })
    }

    /// Copies a prompt for the person's agent: to change a spot of the spots folder, or to review any other spot.
    public func copyListingPrompt(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }) else { return }
        guard !item.isOwn else { return copyPrompt(changing: Entry(spot: item.spot, run: nil)) }
        let prompt = host.agentPrompt(for: folder.url)
        Task {
            do {
                host.confirm(try await prompt.copy(prompt.reviewing(item.spot.url)))
            } catch {
                host.notify("The prompt for \(item.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Takes whether the person types in the dock's search.
    public func searchesDock(_ isOn: Bool) {
        if isSearchingDock != isOn { isSearchingDock = isOn }
    }

    /// Reads the spots of this folder that are off and the packages of its files in the store, and makes the store again.
    func refreshDock(in folder: SpotsFolder) {
        dockRead?.cancel()
        dockStamp = folder.stamp()
        (dockOff, dockPublications) = Self.readDock(in: folder, store: files.store)
        composeDock()
    }

    /// Reads what the store needs from this folder off the main thread, and makes the store again when the read lands.
    func refreshDock(in folder: SpotsFolder) async {
        dockRead?.cancel()
        let store = files.store
        let read = await Task.detached(priority: .userInitiated) { (folder.stamp(), Self.readDock(in: folder, store: store)) }.value
        dockStamp = read.0
        (dockOff, dockPublications) = read.1
        composeDock()
    }

    /// Reads what the store needs from this folder off the main thread, so that Edit Spots starts with no read of the disk.
    func readDockLater(in folder: SpotsFolder) {
        dockRead?.cancel()
        let store = files.store
        dockRead = Task { [weak self] in
            let read = await Task.detached(priority: .utility) { (folder.stamp(), Self.readDock(in: folder, store: store)) }.value
            guard let self, !Task.isCancelled else { return }
            (self.dockOff, self.dockPublications) = read.1
            self.dockStamp = read.0
        }
    }

    /// The spots of this folder that are off, and whether the store's package of each file of the folder is current.
    nonisolated static func readDock(in folder: SpotsFolder, store: URL) -> ([SpotDock.Item], [String: SpotDock.Publication]) {
        let own = (try? SpotsFolder(url: folder.url).keptScan()) ?? ScanResult(files: [], refused: [])
        return (offSpots(in: folder, own: own.files), publications(of: own, in: folder, store: store))
    }

    /// Makes the store from each card of the panel and each spot that is off, and keeps its filter and its search. A part of
    /// a widget, such as a metric that it places or a sheet that it opens, is not one.
    func composeDock() {
        let folder = self.folder
        let choice = arrangement
        let spots = cards.filter { $0.item == nil && $0.spot.fault == nil }
        let parts = Set(spots.flatMap { $0.spot.places + ($0.spot.opens.map { [$0] } ?? []) })
        let on = spots.filter { !parts.contains($0.id) }.map { entry in
            let origin: SpotDock.Origin = entry.spot.isBuiltIn ? .builtIn : folder.isCore(entry.spot) ? .core : .mine
            return SpotDock.Item(spot: entry.spot, origin: origin, state: entry.isOnGrid ? .onGrid : .searchOnly, size: entry.size, publication: dockPublications[entry.id])
        }
        let off = dockOff.map { SpotDock.Item(spot: $0.spot, origin: $0.origin, size: choice.size(of: $0.id) ?? defaultArrangement.size(of: $0.id), publication: dockPublications[$0.id]) }
        let next = SpotDock(items: on + off, query: dock.query, section: dock.section, opened: dock.opened, isSheetOut: dock.isSheetOut)
        if next != dock { dock = next }
    }

    /// The core spots of this folder that are not on, and the spots of its files that the person turned off. A sheet that
    /// another spot opens is not one.
    private nonisolated static func offSpots(in folder: SpotsFolder, own: [SpotFile]) -> [SpotDock.Item] {
        let ownIDs = Set(own.map(\.id))
        let core = folder.keptCoreChoices()
            .filter { !folder.enabled.contains(SpotsFolder.coreID(of: $0)) && !ownIDs.contains(SpotsFolder.coreID(of: $0)) }
        let turnedOff = own.filter { folder.disabled.contains($0.id) }.flatMap(\.spots)
        let opened = Set(turnedOff.compactMap(\.opens))
        return core.map { SpotDock.Item(spot: $0) } + turnedOff.filter { !opened.contains($0.id) }.map { SpotDock.Item(spot: $0, origin: .mine) }
    }

    /// Whether the minus of Edit Spots can turn this spot off. A built-in and a card of faults stay on.
    public func turnsOff(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.host == nil && !entry.spot.isBuiltIn && entry.spot.fault == nil
    }

    /// Turns a spot off from Edit Spots: its card leaves the panel, and the dock shows it.
    public func turnOff(_ id: String) {
        guard let entry = visible.first(where: { $0.id == id }), turnsOff(entry) else { return }
        turn(entry.spot, on: false)
    }

    /// Turns a spot of the store that is off on: its card takes a place in the panel.
    public func turnOn(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id && $0.state == .off }) else { return }
        turn(item.spot, on: true)
    }

    /// Puts a spot of the store on the grid, in search only, or off. A built-in spot is never off. A spot that comes on
    /// takes the place of the grid or of search only after it loads.
    public func setState(_ state: SpotDock.State, of id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.state != state else { return }
        if state == .off {
            guard item.origin != .builtIn else { return }
            turn(item.spot, on: false)
            return
        }
        if item.state == .off, !turn(item.spot, on: true) { return }
        if cards.first(where: { $0.id == id })?.isOnGrid != (state == .onGrid) { setOnGrid(state == .onGrid, for: id) }
    }

    /// Adds each spot of the store that is not added, and loads the spots again on the edit motion.
    public func turnOnAll() {
        let off = dock.items.filter { $0.state == .off }
        guard !off.isEmpty else { return }
        do {
            for item in off { try files.config.turn(folder.fileID(of: item.spot), on: true) }
        } catch {
            host.notify("Some spots were not turned on. \(Self.reason(error))")
        }
        change(.edit) { reload() }
    }

    /// Moves the file of a spot of the store that is off to the Trash, as Delete does in the action menu, so `⌘Z` puts it
    /// back.
    public func delete(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn, item.state == .off else { return }
        remove(Entry(spot: item.spot, run: nil))
    }

    /// Turns a spot on or off in the config, and loads the spots again on the edit motion, after `ending` runs in it.
    @discardableResult
    func turn(_ spot: Spot, on isOn: Bool, ending: () -> Void = {}) -> Bool {
        do {
            try files.config.turn(folder.fileID(of: spot), on: isOn)
        } catch {
            host.notify("\(spot.name) was not turned \(isOn ? "on" : "off"). \(Self.reason(error))")
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
            tip = nil
            drag = nil
            landing = nil
            carry = nil
            arrival = nil
            resize = nil
            pointerMove = nil
            if lift.offset != .zero { lift.offset = .zero }
            selected = 0
            isSearchingDock = false
            dock.opened = nil
            dock.isSheetOut = false
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
        if isSearchingDock {
            searchDock("")
            isSearchingDock = false
            return
        }
        if drag != nil || resize != nil || carry != nil {
            if key.name == "escape" {
                cancelDrag()
                cancelResize()
            }
            return
        }
        if openSheet(on: key) { return }
        if key.name == "escape", let id = dock.opened { return openListing(id) }
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

    private func moveSelectedSpot(by step: Int, in order: [String]) {
        guard order.indices.contains(selected),
              let place = grid.nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
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
        if let next = grid.nextSize(of: selected, in: sizes, among: self.sizes(of: entry)) { prefer(next, for: entry.id) }
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
        tip = nil
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
            let name = { (spot: String) in self.entries.first { $0.id == spot }?.spot.name ?? spot }
            host.notify("\(letter.name.uppercased()) now runs \(name(id)), so \(name(holder)) has no letter.")
        }
        saveArrangement(selecting: id)
    }

    /// Writes the arrangement, and lays out the cards from it on the edit motion, after `ending` runs in that motion.
    /// `landed` runs when the motion ends.
    func saveArrangement(selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        do {
            try files.config.write(arrangement)
            tookOwnWrite()
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
        change(.edit, {
            ending()
            rebuildEntries()
            composeDock()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
            carryHome()
        }, completion: landed)
    }
}
