import Foundation

extension SpotsModel {
    public func failure(of entry: Entry) -> String? {
        failure(of: entry.item?.run, in: entry.spot.id)
    }

    public func refusals(of item: String?, in spot: String) -> Int {
        shakes[Self.shakeKey(of: item, in: spot)] ?? 0
    }

    static func shakeKey(of item: String?, in spot: String) -> String {
        "\(spot)\n\(item ?? "")"
    }

    public func failure(of item: String?, in spot: String) -> String? {
        guard let run = sheets[spot], run.failedItem == item else { return nil }
        return run.failure
    }

    public var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    public var showsSearch: Bool {
        if let form { return form.draft.choices != nil && !isEditing }
        return !isEditing && openSheet?.takesKeys != false
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
        guard let id, form?.entry.id != id, let panel = sheets[id]?.panel, panel.holdsParts else { return nil }
        return panel
    }

    public var openSheet: SpotRun? {
        openSheetID.flatMap { sheets[$0] }
    }

    public var openEntry: Entry? {
        sheetEntry(openSheetID)
    }

    public func sheetEntry(_ id: String?) -> Entry? {
        guard let id else { return nil }
        if let held = leavingSheet(id) { return held.entry }
        if let entry = entry(id) { return entry }
        guard OwnedSheet.owner(of: id) != nil, let run = sheets[id] else { return nil }
        return Entry(spot: run.spot, run: run)
    }

    public var openItems: ItemList? {
        openSheet?.list
    }

    public func stepBack() -> Bool {
        asOnePress {
            if !searchText.isEmpty {
                search("")
            } else if popPage() {
            } else if openSheetID != nil {
                closeSheet(moving: isShown)
            } else {
                return false
            }
            return true
        }
    }

    public func place(ofSheet id: String) -> SheetPlace {
        return arrangement.isWindow(of: id) ?? defaultArrangement.isWindow(of: id) ?? false ? .window : .panel
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

    @discardableResult
    public func openSettings(at place: SettingsPage? = nil) -> Bool {
        if case .spotOf(let id) = place, let entry = cards.first(where: { $0.id == id && $0.item == nil }), !hasSettings(entry) {
            toast(.failure("\(entry.state.title) has nothing to set."))
            return false
        }
        return asOnePress {
            settingsBook.open(at: place)
            host.showSettings()
            return true
        }
    }

    public func pushFirst(_ id: String, moving: Bool, title: String? = nil, source: String? = nil) {
        if let spot = sheets[id]?.spot, spot.opensToKeys {
            openSettings(at: .spotOf(id))
            return
        }
        if place(ofSheet: id) == .window { return openWindow(id) }
        if openSheetID == nil { endFlow() }
        let page = FlowSheet(spot: id, title: title, source: source)
        flow.push(page)
        sheets[id]?.show(page)
        waitPush(moving: moving && openSheetID != nil && openSheetID != id && flow.index > 0)
        present(id, moving: moving)
    }

    func leavingSheet(_ id: String?) -> ClosingSheet? {
        guard transition.phase == .closing, let held = closingSheet, held.id == id else { return nil }
        return held
    }

    func present(_ id: String, moving: Bool) {
        if let shown = openSheetID, shown != id { stopRecording() }
        sheets[id]?.open(waits: moving) { [weak self] in self?.showSheet(id, moving: moving) }
    }

    public func closeSheet(moving: Bool) {
        asOnePress {
            let closing = moving ? openSheetID.flatMap { id in
                sheets[id].map { ClosingSheet(id: id, page: SheetPage(run: $0, rect: $0.sheetRect, query: searchText), entry: sheetEntry(id)) }
            } : nil
            if closing != closingSheet { closingSheet = closing }
            pendingAsk = nil
            keys.status = nil
            askedAnswer = nil
            stopRecording()
            showSheet(nil, moving: moving) {
                runs.closeOpen()
                endFlow()
            }
        }
    }

    public func close(_ place: ViewPlace) {
        asOnePress {
            switch place {
            case .card, .sample: break
            case .sheet(let id): if openSheetID == id { closeSheet(moving: true) }
            case .detached(let id): if runs.floating.contains(id) { land(id) }
            }
        }
    }

    public func panelDidHide() {
        isPanelHidden = true
        isAttachmentOpen = false
        if !shakes.isEmpty { shakes = [:] }
        noteMiss()
        finishPick()
        for entry in entries where entry.spot.triggers.search != nil { sheets[entry.id]?.answer("") }
        runs.panelClosed()
        if isFirstLaunch, !isWarming { isFirstLaunch = false }
        endReview()
        if let heldLayout { lay(heldLayout) }
    }

    func showSheet(_ list: String?, moving: Bool, ending: () -> Void = {}) {
        asOnePress {
            guard list != openSheetID else {
                dropWaitingPush()
                return ending()
            }
            if let list, openSheetID != nil, transition.isOpen {
                let swapped = takeWaitingPush { [weak self] in
                    self?.transition.show(list, moves: true)
                    self?.transition.settle(list)
                }
                guard !swapped else { return }
                change(moving ? .sheet(isOpen: true) : nil, {
                    transition.show(list, moves: true)
                }) { [weak self] in
                    self?.snap { self?.transition.settle(list) }
                }
                return
            }
            dropWaitingPush()
            guard moving, hasPlace(list ?? transition.id) else {
                cutSheet(to: list)
                return ending()
            }
            guard let list else {
                animate(isOpen: false) {
                    transition.hide(moves: true)
                    holdFieldDrop()
                    ending()
                }
                return
            }
            closeMenu(keepsFoot: true)
            snap {
                transition.show(list, moves: true, page: flow.current)
                holdFieldDrop()
            }
            host.nextFrame { [weak self] in
                self?.animate(isOpen: true) { self?.transition.start() }
            }
        }
    }

    func cutSheet(to list: String?) {
        snap {
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
            snap {
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
        if id == openSheetID { recordAskedField() }
    }

    public func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void = {}) {
        host.change(motion, body, completion: completion)
    }

    func snap(_ body: () -> Void) {
        host.change(nil, body, completion: {})
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
        guard let item = openItems?.selectedItem else {
            createFromSearch()
            return
        }
        runItem(item)
    }

    public var createAction: CommandAction? {
        guard let list = openItems, !list.query.isEmpty, list.shown.isEmpty, list.search == .local, let spot = openEntry?.spot else { return nil }
        return spot.frameActions.first { $0.scope == .spot && (try? spot.action($0.callName))?.textInput != nil }
            ?? spot.commands.map(CommandAction.command).first { (try? spot.action($0.callName))?.textInput != nil }
    }

    public func createFromSearch() {
        asOnePress {
            guard let action = createAction, let entry = openEntry else { return }
            let query = openItems?.query ?? ""
            guard let typed = try? entry.spot.action(action.callName), let input = typed.textInput else { return }
            guard typed.lacksInput else { return call(action, of: entry, query) }
            show(.form(typed.itemForm(values: [input.name: query], title: action.title)), of: action, on: (entry, nil), prefill: "")
        }
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
        asOnePress {
            if action == nil, case .push(let spot, let route, let title, let replace)? = item.move, spot.map(opensSheet) ?? true {
                push(FlowSheet(spot: spot ?? entry.id, route: route, title: title ?? (route == nil ? nil : item.title)), replace: replace)
                return
            }
            if place.isDetached {
                if action == nil, item.records { return press(entry.id) }
                remember(item, of: entry)
                sheets[entry.id]?.list.select(run: item.run)
            } else {
                if action == nil, item.records {
                    toggleRecording(id: item.run)
                    return
                }
                if action != nil || (entry.spot.pick == .close && !item.staysOnPick && !entry.spot.takesHandlers) {
                    closingPick = (item, entry)
                    if isShown {
                        host.dismiss()
                    } else {
                        finishPick()
                    }
                }
            }
            let closes = !place.isDetached && entry.spot.takesHandlers && entry.spot.pick == .close && !item.staysOnPick
            if let action {
                perform(action, on: (entry, item))
            } else if entry.spot.takesHandlers, let sheet = sheets[entry.id] {
                if closes { closingPick = (item, entry) }
                Task { [weak self] in
                    let answer = await sheet.answer(toPick: item, closes: closes)
                    guard let self else { return }
                    switch answer {
                    case .form, .stopped: if closingPick?.item == item { closingPick = nil }
                    default: break
                    }
                    guard case .form(let form) = answer else { return }
                    let press = CommandAction(id: ScriptEntry.press.name, title: item.title)
                    switch place {
                    case .window: toast(.failure("\(item.title) asks with a form, which a window does not show yet."))
                    case .float: afterShowing({ host.show() }) { [weak self] in self?.show(.form(form), of: press, on: (entry, item), prefill: "") }
                    case .panel: if isShown { show(.form(form), of: press, on: (entry, item), prefill: "") }
                    }
                }
            } else {
                sheets[entry.id]?.pick(item, closes: closes)
            }
        }
    }
}
