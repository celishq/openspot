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

    public var openPanel: SheetParts? {
        shownParts(of: openList)
    }

    public func shownParts(of id: String?) -> SheetParts? {
        guard let id, form?.entry.id != id else { return nil }
        return sheets[id]?.panel
    }

    public var openSheet: SpotRun? {
        openList.flatMap { sheets[$0] }
    }

    public var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    public var openItems: ItemList? {
        openSheet?.list
    }

    public func stepBack() -> Bool {
        if !searchText.isEmpty {
            searchText = ""
        } else if back() {
        } else if openList != nil {
            closeList(moving: isShown)
        } else {
            return false
        }
        return true
    }

    public func place(ofSheet id: String) -> SheetPlace {
        entries.first { $0.id == id }?.spot.offersWindow == true ? .window : .panel
    }

    func presentSheet(of id: String, moving: Bool, showingPanel: () -> Void = {}) {
        guard place(ofSheet: id) == .panel else { return openWindow(id) }
        showingPanel()
        pushFirst(id, moving: moving)
    }

    public func openSettings() {
        guard let id = spot(openedBy: ActionKey(name: ",", isCommand: true)) else { return }
        pushFirst(id, moving: true)
    }

    public func pushFirst(_ id: String, moving: Bool, title: String? = nil) {
        if place(ofSheet: id) == .window { return openWindow(id) }
        if openList == nil { endFlow() }
        flow.push(FlowSheet(spot: id, title: title))
        sheets[id]?.show(page: nil)
        waitPush(from: moving && openList != nil && openList != id ? 1 : nil)
        present(id, moving: moving)
    }

    func present(_ id: String, moving: Bool) {
        if let shown = openList, shown != id { stopRecording() }
        sheets[id]?.open(waits: moving) { [weak self] in self?.showSheet(id, moving: moving) }
    }

    public func closeList(moving: Bool) {
        formAsk = nil
        stopRecording()
        showSheet(nil, moving: moving)
        runs.closeOpen()
        endFlow()
    }

    public func panelDidHide() {
        finishPick()
        for entry in entries where entry.spot.answers != nil { sheets[entry.id]?.answer("") }
        runs.panelClosed()
        if isFirstLaunch, !isWarming {
            isFirstLaunch = false
            host.confirm(entryKey.openHint)
        }
        endReview()
    }

    func showSheet(_ list: String?, moving: Bool) {
        guard list != openList else { return }
        if let list, openList != nil, transition.isOpen {
            change(moving ? .sheet(isOpen: true) : nil, {
                transition.show(list, moves: true)
                startWaitingPush()
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
        change(nil) {
            transition.show(list, moves: true)
            holdFieldDrop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.animate(isOpen: true) { self?.transition.start() }
        }
    }

    func cutSheet(to list: String?) {
        change(nil) {
            if let list { transition.show(list, moves: false) } else { transition.hide(moves: false) }
            fieldDrop = nil
            showsFieldDrop = false
        }
        if list == nil { endReview() }
    }

    func hasPlace(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == fieldSheet || SpotSheetCard.of(id, in: self) != nil
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
            if transition.phase == .closed { endReview() }
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
        closeList(moving: false)
    }

    private func remember(_ item: SpotItem, of entry: Entry) {
        guard entry.spot.keepsRecent, let sheet = sheets[entry.id] else { return }
        sheet.list.remember(item)
        files.remember(sheet.list.recent, of: entry.id)
    }

    public func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil, in place: SheetPlace = .panel) {
        if action == nil, case .push(let spot, let page, let title, _)? = item.move, spot.map(opensSheet) ?? true {
            push(FlowSheet(spot: spot ?? entry.id, page: page, title: title ?? (page == nil ? nil : item.title)))
            return
        }
        if place.isDetached {
            if action == nil, entry.spot.pickForm != nil || item.records { return press(entry.id) }
            remember(item, of: entry)
            sheets[entry.id]?.list.select(run: item.run)
        } else {
            if action == nil, item.records {
                toggleRecording(id: item.run)
                return
            }
            if action == nil, let form = entry.spot.pickForm {
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
