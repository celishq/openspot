import Foundation

extension SpotsModel {
    public var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    public var showsSearch: Bool {
        if let form { return form.draft.choices != nil && !isEditing }
        return !isEditing && openSheet?.partsKind?.takesKeys != false
    }

    public var fieldTop: SheetTop {
        transition.id.flatMap { sheets[$0]?.top } ?? .plain
    }

    public var openTop: SheetTop {
        openSheet?.top ?? .plain
    }

    public var openParts: SheetParts? {
        shownParts(of: openSheetID)
    }

    public func shownParts(of id: String?) -> SheetParts? {
        guard let id, form?.entry.id != id else { return nil }
        return sheets[id]?.panel
    }

    public var openSheet: SpotRun? {
        openSheetID.flatMap { sheets[$0] }
    }

    public var openEntry: Entry? {
        sheetEntry(openSheetID)
    }

    public func sheetEntry(_ id: String?) -> Entry? {
        guard let id else { return nil }
        if let entry = entry(id) { return entry }
        guard OwnedSheet.owner(of: id) != nil, let run = sheets[id] else { return nil }
        return Entry(spot: run.spot, run: run)
    }

    public var openItems: ItemList? {
        openSheet?.list
    }

    public func stepBack() -> Bool {
        if !searchText.isEmpty {
            searchText = ""
        } else if popPage() {
        } else if openSheetID != nil {
            closeSheet(moving: isShown)
        } else {
            return false
        }
        return true
    }

    public func place(ofSheet id: String) -> SheetPlace {
        arrangement.isWindow(of: id) ?? defaultArrangement.isWindow(of: id) ?? false ? .window : .panel
    }

    func presentSheet(of id: String, showingPanel: () -> Void = {}) {
        guard place(ofSheet: id) == .panel else { return openWindow(id) }
        afterShowing(showingPanel) { [weak self] in
            guard let self else { return }
            pushFirst(id, moving: isShown)
        }
    }

    func afterShowing(_ showingPanel: () -> Void, _ open: @escaping @MainActor () -> Void) {
        let wasShown = isShown
        showingPanel()
        if wasShown { open() } else { host.nextFrame(open) }
    }

    public func openSettings() {
        guard let id = spot(openedBy: ActionKey(name: ",", isCommand: true)) else { return }
        pushFirst(id, moving: true)
    }

    @discardableResult
    func openKeys(of id: String) -> Bool {
        guard let entry = entry(id), let settings = settingsSheet(of: entry) else { return false }
        let moves = isShown
        if !moves { host.show() }
        pushFirst(settings, moving: moves)
        return true
    }

    public func pushFirst(_ id: String, moving: Bool, title: String? = nil, source: String? = nil) {
        if let spot = sheets[id]?.spot, spot.opensToKeys {
            openKeys(of: id)
            return
        }
        if let owner = SpotSettings.owner(of: id), let spot = sheets[owner]?.spot ?? entry(owner)?.spot {
            runs.settingsSheet(of: spot)
        }
        if place(ofSheet: id) == .window { return openWindow(id) }
        if openSheetID == nil { endFlow() }
        let page = FlowSheet(spot: id, title: title, source: source)
        flow.push(page)
        sheets[id]?.show(page)
        waitPush(moving: moving && openSheetID != nil && openSheetID != id && flow.index > 0)
        present(id, moving: moving)
    }

    func present(_ id: String, moving: Bool) {
        closingPage = nil
        if let shown = openSheetID, shown != id { stopRecording() }
        sheets[id]?.open(waits: moving) { [weak self] in self?.showSheet(id, moving: moving) }
    }

    public func closeSheet(moving: Bool) {
        closingPage = moving ? openSheetID.flatMap { id in sheets[id].map { SheetPage(run: $0, rect: $0.sheetRect, query: searchText) } } : nil
        pendingAsk = nil
        keys.status = nil
        askedAnswer = nil
        stopRecording()
        showSheet(nil, moving: moving)
        runs.closeOpen()
        endFlow()
    }

    public func close(_ place: ViewPlace) {
        switch place {
        case .card, .sample: break
        case .sheet(let id): if openSheetID == id { closeSheet(moving: true) }
        case .detached(let id): if runs.floating.contains(id) { land(id) }
        }
    }

    public func panelDidHide() {
        isPanelHidden = true
        noteMiss()
        finishPick()
        for entry in entries where entry.spot.answers != nil { sheets[entry.id]?.answer("") }
        runs.panelClosed()
        if isFirstLaunch, !isWarming { isFirstLaunch = false }
        endReview()
        if let heldLayout { lay(heldLayout) }
    }

    func showSheet(_ list: String?, moving: Bool) {
        guard list != openSheetID else { return dropWaitingPush() }
        if let list, openSheetID != nil, transition.isOpen {
            let swapped = takeWaitingPush { [weak self] in
                self?.transition.show(list, moves: true)
                self?.transition.settle(list)
            }
            guard !swapped else { return }
            change(moving ? .sheet(isOpen: true) : nil, {
                transition.show(list, moves: true)
            }) { [weak self] in
                self?.change(nil) { self?.transition.settle(list) }
            }
            return
        }
        dropWaitingPush()
        guard moving, hasPlace(list ?? transition.id) else { return cutSheet(to: list) }
        guard let list else {
            animate(isOpen: false) {
                transition.hide(moves: true)
                holdFieldDrop()
            }
            return
        }
        closeMenu(keepsFoot: true)
        change(nil) {
            transition.show(list, moves: true, page: flow.current)
            holdFieldDrop()
        }
        host.nextFrame { [weak self] in
            self?.animate(isOpen: true) { self?.transition.start() }
        }
    }

    func cutSheet(to list: String?) {
        change(nil) {
            if let list { transition.show(list, moves: false, page: flow.current) } else { transition.hide(moves: false) }
            fieldDrop = nil
            showsFieldDrop = false
        }
        if list == nil { endReview() }
    }

    func hasPlace(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == fieldSheet || sheets[id] != nil || SpotSheetCard.of(id, in: self) != nil
    }

    private func animate(isOpen: Bool, _ body: () -> Void) {
        var motion = 0
        change(.sheet(isOpen: isOpen), {
            body()
            motion = transition.motion
        }) { [weak self] in
            guard let self else { return }
            let isInstall = transition.id != nil && transition.id == fieldSheet
            change(nil) {
                self.transition.finish(motion)
                if isInstall, self.transition.phase == .open {
                    self.fieldDrop = nil
                    self.showsFieldDrop = false
                }
            }
            if isInstall, transition.phase == .closed { hideFieldDrop() }
            if transition.phase == .closed {
                endReview()
                closingPage = nil
            }
        }
    }

    private func holdFieldDrop() {
        guard let drop = reviewDrop else { return }
        fieldDrop = drop
        showsFieldDrop = true
    }

    func followSpotDrop(from old: SpotDrop?) {
        guard spotDrop != old else { return }
        if let drop = spotDrop {
            change(.sheet(isOpen: true)) {
                fieldDrop = drop
                showsFieldDrop = true
            }
        } else if !isReviewing {
            hideFieldDrop()
        }
    }

    private func hideFieldDrop() {
        change(.sheet(isOpen: false), { showsFieldDrop = false }) { [weak self] in
            guard let self, !showsFieldDrop else { return }
            fieldDrop = nil
        }
    }

    func bringParts(of id: String, _ bring: () -> Void) {
        change(transition.id == id && transition.isOpen ? PanelMotion.sheet(isOpen: true) : nil, bring)
        if id == openSheetID { recordAskedField() }
    }

    public func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void = {}) {
        host.change(motion, body, completion: completion)
    }

    public func moveItemToEdge(last: Bool) {
        openSheet?.list.moveToEdge(last: last)
    }

    public func moveItem(by step: Int) {
        openSheet?.list.move(by: step)
    }

    public func moveItemLine(by lines: Int) {
        openSheet?.list.moveLine(by: lines)
    }

    public func runSelectedItem() {
        openSheet?.landRows()
        guard let item = openItems?.selectedItem else {
            createFromSearch()
            return
        }
        runItem(item)
    }

    public var createAction: CommandAction? {
        guard let list = openItems, !list.query.isEmpty, list.shown.isEmpty, list.search == .local else { return nil }
        return openEntry?.spot.actions.first { $0.scope == .spot && $0.isForm }
    }

    public func createFromSearch() {
        openSheet?.landRows()
        guard let action = createAction, let entry = openEntry else { return }
        openForm(action, on: (entry, nil), prefill: openItems?.query ?? "")
    }

    public func runItem(_ item: SpotItem) {
        guard let entry = openEntry else { return }
        pick(item, of: entry)
    }

    public func finishPick() {
        guard let pick = closingPick else { return }
        closingPick = nil
        remember(pick.item, of: pick.entry)
        closeSheet(moving: false)
    }

    private func remember(_ item: SpotItem, of entry: Entry) {
        guard entry.spot.keepsRecent, let sheet = sheets[entry.id] else { return }
        sheet.list.remember(item)
        files.remember(sheet.list.recent, of: entry.id)
    }

    public func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil, in place: SheetPlace = .panel) {
        if action == nil, !item.records, entry.spot.holdsSettings, let settings = entry.spot.settingsSheet, let key = settings.field(of: item.run) {
            _ = changeSetting(key, of: settings.spot)
            return
        }
        if action == nil, case .push(let spot, let route, let title, let replace)? = item.move, spot.map(opensSheet) ?? true {
            push(FlowSheet(spot: spot ?? entry.id, route: route, title: title ?? (route == nil ? nil : item.title)), replace: replace)
            return
        }
        if place.isDetached {
            if action == nil, (entry.spot.pickForm ?? item.form) != nil || item.records { return press(entry.id) }
            remember(item, of: entry)
            sheets[entry.id]?.list.select(run: item.run)
        } else {
            if action == nil, item.records {
                toggleRecording(id: item.run)
                return
            }
            if action == nil, let form = entry.spot.pickForm ?? item.form {
                openForm(form, on: (entry, item))
                return
            }
            if action != nil || (entry.spot.pick == .close && !item.staysOnPick) {
                closingPick = (item, entry)
                if isShown {
                    host.dismiss()
                } else {
                    finishPick()
                }
            }
        }
        if let action {
            sheets[entry.id]?.run(action, item: item)
        } else {
            sheets[entry.id]?.pick(item)
        }
    }
}
