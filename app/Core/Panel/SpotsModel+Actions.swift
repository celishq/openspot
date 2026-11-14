import Foundation
import Observation

extension SpotsModel {
    private var target: Target? {
        if let entry = openEntry {
            return (entry, openSheet?.selectedItem)
        }
        guard let entry = selectedEntry else { return nil }
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.spot.id }) { return (list, item) }
        return (entry, nil)
    }

    public func handleKey(_ key: ActionKey) -> Bool {
        if menu != nil {
            return handleMenuKey(key)
        }
        if isEditing {
            handleEditKey(key)
            return true
        }
        if let form {
            let isList = form.draft.choices != nil
            switch key {
            case ActionKey(name: "return", isCommand: true): submitForm()
            case ActionKey(name: "return") where isList: submitForm()
            case ActionKey(name: "a", isCommand: true, isShift: true) where form.draft.isMultiple:
                if let all = form.draft.selectingAll() { send(form, all) }
            case ActionKey(name: "up") where isList: self.form?.draft.move(by: -1)
            case ActionKey(name: "down") where isList: self.form?.draft.move(by: 1)
            case ActionKey(name: "escape") where form.draft.choices?.query.isEmpty == false: self.form?.draft.search("")
            case ActionKey(name: "escape"): cancelForm()
            default: return false
            }
            return true
        }
        openSheet?.landRows()
        if openList != nil, let handled = handleFlowKey(key) { return handled }
        if key == Self.undoKey, openList == nil, searchText.isEmpty, undoRemoval() { return true }
        if key == ActionKey(name: "return", isCommand: true), openSelected() { return true }
        if let panel = openPanel, !panel.showsRows { return handlePanelKey(key, panel) }
        if let panel = openPanel, handleRowsPanelKey(key, panel) { return true }
        if let part = openPanel?.parts.first(where: { $0.key == key }) {
            pressPart(part)
            return true
        }
        if key == ActionKey(name: "escape"), let target, let action = target.entry.spot.actions(for: target.item).first(where: { $0.key == key }) {
            run(action, on: target)
            return true
        }
        if key == ActionKey(name: "escape") {
            if !stepBack() { host.dismiss() }
            return true
        }
        guard let target else { return openSheet(on: key) }
        if key == ActionKey(name: "k", isCommand: true) {
            openMenu(on: target)
            return menu != nil
        }
        var noHooks: Set<String> = []
        if searchText.isEmpty, !target.entry.spot.actions(for: target.item).contains(where: { $0.key == key }),
           let offer = offered(on: target, yes: &noHooks, asks: false).first(where: { $0.action.key == key }) {
            if offer.action.confirm != nil {
                openMenu(on: target)
                menu?.select(offer.action)
                pressMenu()
            } else {
                run(offer.action, offeredBy: offer.owner, on: target)
            }
            return true
        }
        guard let action = target.entry.spot.actions(for: target.item).first(where: { $0.key == key }) else { return openSheet(on: key) }
        if action.confirm != nil {
            openMenu(on: target)
            menu?.select(action)
            pressMenu()
        } else {
            run(action, on: target)
        }
        return true
    }

    func openSheet(on key: ActionKey) -> Bool {
        guard openList == nil, let id = spot(openedBy: key) else { return false }
        endEditing(moving: false)
        pushFirst(id, moving: true)
        return true
    }

    func spot(openedBy key: ActionKey) -> String? {
        arrangement.spot(openedBy: key, over: defaultArrangement).flatMap { id in entries.contains { $0.id == id } ? id : nil }
    }

    static let openLabel = "⌘⏎"

    public func pressHint(_ label: String) {
        guard let key = ActionKey(label: label) else { return }
        if !handleKey(key), key == ActionKey(name: "return") { runSelected() }
    }

    private func handlePanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
        if let part = panel.parts.first(where: { $0.key == key }) {
            pressPart(part)
            return true
        }
        if key == ActionKey(name: "escape") {
            if !back() { closeList(moving: true) }
            return true
        }
        if panel.scrollsByArrows, key == ActionKey(name: "up") || key == ActionKey(name: "down") {
            openSheet?.scrollPanel(by: key.name == "up" ? -1 : 1)
            return true
        }
        guard let part = panel.selectedPart else { return false }
        return handleFocusKey(key, part)
    }

    private func handleRowsPanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
        if let part = panel.selectedPart { return handleFocusKey(key, part) }
        openSheet?.landRows()
        guard key == ActionKey(name: "down"), openItems?.isOnLastLine != false else { return false }
        return openSheet?.leaveRows() == true
    }

    private func handleFocusKey(_ key: ActionKey, _ part: SpotPart) -> Bool {
        switch key {
        case ActionKey(name: "up"), ActionKey(name: "down"):
            let moved = openSheet?.movePartLine(by: key.name == "up" ? -1 : 1) ?? false
            return moved || !part.isEditable
        case ActionKey(name: "left"), ActionKey(name: "right"):
            guard !part.isEditable else { return false }
            let step = key.name == "left" ? -1 : 1
            if case .slider(let level, let low, let high) = part.control {
                let next = min(max(level + Double(step) * max((high - low) / 20, 1), low), high)
                setPart(part, to: String(Int(next.rounded())))
            } else {
                openSheet?.movePart(by: step)
            }
        case ActionKey(name: "return"):
            guard !part.isEditable else { return false }
            useSelected(part)
        default:
            return false
        }
        return true
    }

    private func useSelected(_ part: SpotPart) {
        switch part.control {
        case .shortcut: toggleRecording(part)
        case .toggle(let on): setPart(part, to: on ? "false" : "true")
        case .menu: openSheet?.openMenu(of: part)
        case .slider: break
        default: pressPart(part)
        }
    }

    public func focusPart(_ part: SpotPart) {
        openSheet?.focusPart(part.id)
    }

    public func setPart(_ part: SpotPart, to value: String) {
        openSheet?.set(part, to: value)
    }

    public func pressPart(_ part: SpotPart) {
        openSheet?.press(part)
        if part.closes, isShown { host.dismiss() }
    }

    public func toggleRecording(_ part: SpotPart) {
        toggleRecording(id: part.id)
    }

    public func toggleRecording(id: String) {
        if recording == id {
            stopRecording()
        } else {
            recording = id
            host.setEntryKey(on: false)
        }
    }

    public func stopRecording() {
        guard recording != nil else { return }
        recording = nil
        host.setEntryKey(on: true)
    }

    public func record(code: UInt32, modifiers: Shortcut.Modifiers) {
        if isEditing { return recordLetter(code: code, modifiers: modifiers) }
        guard let shortcut = Shortcut(code: code, modifiers: modifiers) else {
            host.notify("Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.")
            return
        }
        if takesShake, shortcut.isAppKey {
            host.notify("`\(shortcut.label)` belongs to the apps on the Mac. Hold `⌥` or `⌃` with a key, or tap one key such as `⌥`.")
            return
        }
        let part = openPanel?.parts.first { $0.id == recording }
        let item = openItems?.shown.first { $0.run == recording }
        stopRecording()
        if let part { setPart(part, to: shortcut.text) }
        if let item, let entry = openEntry { give(shortcut.text, to: item, of: entry) }
    }

    private func give(_ key: String, to item: SpotItem, of entry: Entry) {
        sheets[entry.id]?.set(item, to: key)
        guard entry.spot.keyList == nil else { return }
        closingPick = (item, entry)
        if isShown {
            host.dismiss()
        } else {
            finishPick()
        }
    }

    public var takesShake: Bool {
        guard let recording else { return false }
        return openItems?.shown.first { $0.run == recording }?.takesShake ?? false
    }

    public var recordingWords: String {
        takesShake ? "Press keys or shake" : "Press keys"
    }

    public func recordShake() {
        recordTrigger(.shake)
    }

    public func recordTap(_ modifier: Shortcut.Modifiers) {
        recordTrigger(.tap(modifier))
    }

    private func recordTrigger(_ trigger: Trigger) {
        guard takesShake, let recording, let entry = openEntry, let item = openItems?.shown.first(where: { $0.run == recording }) else { return }
        stopRecording()
        give(trigger.text, to: item, of: entry)
    }

    private func handleMenuKey(_ key: ActionKey) -> Bool {
        let types = menu?.isSearchable == true && !key.isCommand
        switch key {
        case ActionKey(name: "k", isCommand: true), ActionKey(name: "escape"): closeMenu()
        case ActionKey(name: "up"): menu?.move(by: -1)
        case ActionKey(name: "down"): menu?.move(by: 1)
        case ActionKey(name: "return"): pressMenu()
        case ActionKey(name: "right") where menu?.selectedRow?.children.isEmpty == false: _ = menu?.enterSelected()
        case ActionKey(name: "left") where menu?.parent != nil: _ = menu?.back()
        default:
            guard !types, let action = menu?.rows.compactMap(\.action).first(where: { $0.key == key }) else { return !types }
            menu?.select(action)
            pressMenu()
        }
        return true
    }

    public func dragMenu(to point: CGPoint) {
        if let row = menuRow(at: point) { self.point(at: .menuRow(row)) }
    }

    public func releaseMenu(at point: CGPoint) {
        if let row = menuRow(at: point) { pressMenu(row: row) }
    }

    private func menuRow(at point: CGPoint) -> Int? {
        guard let menu, let frame = menuFrame else { return nil }
        return frame.row(at: point, of: menu)
    }

    public var menu: ActionMenu? {
        get { menuSession?.phase == .closing ? nil : menuSession?.menu }
        set {
            guard let newValue, menu != nil else { return }
            menuSession?.menu = newValue
            placeSubmenu()
        }
    }

    func placeSubmenu() {
        var row: CGRect?
        if let menu, let submenu = menu.submenu, let frame = menuFrame, menuSession?.phase != .closing {
            row = frame.rowRect(submenu.parent, of: menu)
        }
        guard row != menuSession?.submenuRow else { return }
        menuSession?.submenuRow = row
        if let row, let menu, let frame = menuFrame {
            host.showSubmenu(beside: row, of: frame.rect(of: menu))
        } else {
            host.hideSubmenu()
        }
    }

    public func pointSubmenu(row: Int) {
        menu?.pointSubmenu(at: row)
    }

    public func pressSubmenu(row: Int) {
        menu?.pointSubmenu(at: row)
        pressMenu()
    }

    public var menuTarget: Target? {
        menu == nil ? nil : menuSession?.target
    }

    public func placeMenu(_ frame: ActionMenuFrame) {
        guard menu != nil, frame != menuFrame else { return }
        menuFrame = frame
        if menuSession?.phase != .opening { growBackdrop() }
        placeSubmenu()
    }

    public func menuItemAtRest(_ item: CGRect) -> CGRect {
        guard focus(ofCard: selected) == .focused, let size = placements.first(where: { $0.index == selected })?.size else { return item }
        let width = SpotTokens.width(columns: size.columns) * MotionTokens.focusedScale
        let height = SpotTokens.height(rows: size.rows) * MotionTokens.focusedScale
        return CGRect(x: item.midX - width / 2, y: item.midY - height / 2, width: width, height: height)
    }

    private func growBackdrop() {
        let height = menuFrame.map { $0.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock } ?? 0
        if height != menuBackdropHeight { menuBackdropHeight = height }
    }

    public func searchMenu(_ text: String) {
        menu?.search(text)
    }

    public func openMenu(at point: CGPoint) {
        let origin = gridOrigin
        guard openList == nil, !isEditing, let id = card(at: CGPoint(x: point.x - origin.x, y: point.y - origin.y)), let index = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = index
        if let target { openMenu(on: target) }
    }

    private func openMenu(on target: Target) {
        var yes: Set<String> = []
        menuSession = actionMenu(on: target, yes: &yes, asks: true).map { ActionMenuSession(menu: $0, target: target, hookYes: yes) }
        DispatchQueue.main.async { [weak self] in
            guard let self, menuSession?.phase == .opening else { return }
            change(.sheet(isOpen: true), {
                self.menuSession?.phase = .open
                self.growBackdrop()
            }, completion: { [weak self] in
                if self?.menuSession?.phase == .open { self?.menuSession?.phase = .settled }
            })
        }
    }

    private func actionMenu(on target: Target) -> ActionMenu? {
        var none: Set<String> = []
        return actionMenu(on: target, yes: &none, asks: false)
    }

    private func actionMenu(on target: Target, yes: inout Set<String>, asks: Bool) -> ActionMenu? {
        let isOpenList = openList == target.entry.id
        return ActionMenu(
            spot: target.entry.spot,
            item: target.item,
            showsOpen: !isOpenList || target.item != nil,
            offered: offered(on: target, yes: &yes, asks: asks)
        )
    }

    private func offered(on target: Target, yes: inout Set<String>, asks: Bool) -> [OfferedAction] {
        guard openList == nil, target.item == nil, let origin = origin(of: target.entry.spot) else { return [] }
        let word = OfferedAction.originWords.first { $0.value == origin }?.key ?? ""
        var shown: [OfferedAction] = []
        for spot in sheets.values.map(\.spot).sorted(by: { $0.id < $1.id }) {
            var hidden: [String] = []
            for offer in spot.offeredActions {
                let id = offer.action.id
                let shows = offer.fits(origin) && !hidden.contains { id.hasPrefix($0 + ".") } && hookSaysYes(offer, of: spot, on: target, origin: word, yes: &yes, asks: asks)
                if shows { shown.append(offer) } else { hidden.append(id) }
            }
        }
        return shown
    }

    private func hookSaysYes(_ offer: OfferedAction, of spot: Spot, on target: Target, origin: String, yes: inout Set<String>, asks: Bool) -> Bool {
        guard let when = offer.when else { return true }
        let key = "\(spot.id) \(offer.action.id)"
        if yes.contains(key) { return true }
        guard asks else { return false }
        let card = target.entry.id
        let answer = runs.ask(when, of: spot, card: card, origin: origin) { [weak self] said in
            guard said, let self, let session = menuSession, session.phase != .closing, session.target.entry.id == card, session.menu.parent == nil else { return }
            var answers = session.hookYes
            answers.insert(key)
            guard var menu = actionMenu(on: session.target, yes: &answers, asks: false) else { return }
            menu.search(session.menu.query)
            if let action = session.menu.selectedRow?.action { menu.select(action) }
            menuSession?.hookYes = answers
            menuSession?.menu = menu
        }
        if answer == true { yes.insert(key) }
        return answer == true
    }

    func origin(of spot: Spot) -> SpotOrigin? {
        if spot.fault != nil { return .mine }
        guard spot.host == nil else { return nil }
        if spot.isBuiltIn { return .builtIn }
        return folder.isCore(spot) ? .core : .mine
    }

    public func run(_ action: CommandAction, offeredBy owner: String, on target: Target) {
        if action.after == .close, isShown { host.dismiss() }
        sheets[owner]?.run(action, item: SpotItem(title: target.entry.state.title, run: target.entry.id))
    }

    public var hint: String {
        if recording != nil, isEditing { return "Press a letter   ⌫ Remove   Esc Cancel" }
        if recording != nil { return "Esc Cancel" }
        if isEditing { return "S Size   H Hide   L Letter   ⇧ Arrows Move   Esc Done" }
        if spotDrop != nil { return "Nothing runs until you press ⌘⏎" }
        let escape = flow.behind == nil ? "Close" : "Back"
        if let panel = openPanel, !panel.showsRows || panel.drawsKeys { return panel.hint(escape: escape) { work(of: $0) != nil } }
        if let soleHint { return soleHint }
        let keys = target.flatMap { target in
            let opens = openList == nil && target.item == nil && target.entry.spot.pressRuns && target.entry.kind.opensSheet
            return actionMenu(on: target)?.hint(
                stopping: { sheets[target.entry.id]?.work(of: $0, item: target.item) != nil },
                second: opens ? "\(Self.openLabel) Settings" : nil
            )
        } ?? "Esc \(escape)"
        return selectedGlyphTitle.map { "\($0)  \(keys)" } ?? keys
    }

    public func followHint() {
        guard !followsHint else { return }
        followsHint = true
        takeHint()
    }

    private func takeHint() {
        hintTakes += 1
        let words = HintWords(withObservationTracking { hint } onChange: { [weak self] in
            Task { @MainActor in self?.takeHint() }
        })
        let motion: PanelMotion? = isEditing || hintIsForEdit || fieldDrop != nil ? .fade : nil
        hintIsForEdit = isEditing
        if openList == nil, spotDrop == nil {
            if words != gridHint { change(motion, { gridHint = words }) }
        } else {
            takeSheetHint(words, motion: motion)
        }
    }

    func takeSheetHint(_ words: HintWords, motion: PanelMotion? = nil) {
        if words != sheetHint { change(motion, { sheetHint = words }) }
    }

    private var selectedGlyphTitle: String? {
        guard openList == nil, let entry = selectedEntry, entry.kind != .widget,
              placements.first(where: { $0.index == selected })?.size == .small
        else { return nil }
        return entry.state.title
    }

    public func closeMenu() {
        guard menu != nil else { return }
        if menuSession?.submenuRow != nil {
            menuSession?.submenuRow = nil
            host.hideSubmenu()
        }
        change(.sheet(isOpen: false), { menuSession?.phase = .closing }, completion: { [weak self] in
            if self?.menuSession?.phase == .closing { self?.menuSession = nil }
        })
    }

    public func pressMenu(row: Int) {
        guard let menu, menu.shown.indices.contains(row) else { return }
        guard menu.shown[row].children.isEmpty else { return point(at: .menuRow(row)) }
        _ = self.menu?.back()
        self.menu?.move(by: row - menu.selected)
        pressMenu()
    }

    private func pressMenu() {
        let isRunning = menu?.selectedRow.map { work(of: $0) != nil } ?? false
        guard let row = menu?.press(isRunning: isRunning), let target = menuTarget else { return }
        if !isRunning, let action = row.action, action.isForm {
            openForm(action, on: target)
            return
        }
        closeMenu()
        if let action = row.action, let owner = row.owner {
            run(action, offeredBy: owner, on: target)
        } else if let action = row.action {
            run(action, on: target)
        } else if let item = target.item {
            pick(item, of: target.entry)
        } else {
            run(target.entry)
        }
    }

    public func run(_ action: CommandAction, on target: Target, in place: SheetPlace = .panel) {
        if place.isDetached {
            if action.isForm || action.confirm != nil, place == .window {
                host.notify("\(action.title) asks with a form or a second press, which a window does not show yet.")
            } else if action.isForm || action.confirm != nil {
                press(target.entry.id)
            } else {
                sheets[target.entry.id]?.run(action, item: target.item)
            }
        } else if action.isForm {
            openForm(action, on: target)
        } else if action.after == .stay {
            sheets[target.entry.id]?.run(action, item: target.item)
        } else if let item = target.item {
            pick(item, of: target.entry, action: action)
        } else {
            if isShown { host.dismiss() }
            sheets[target.entry.id]?.run(action, item: nil)
        }
    }

    public func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        guard place(ofSheet: target.entry.id) == .panel else {
            return host.notify("\(action.title) asks with a form, which a window does not show yet.")
        }
        let ask = UUID()
        formAsk = ask
        Task {
            do {
                guard let form = try await sheets[target.entry.id]?.form(action, item: target.item), formAsk == ask else { return }
                formAsk = nil
                closeMenu()
                let opensSheet = openList != target.entry.id
                if opensSheet {
                    pushFirst(target.entry.id, moving: isShown)
                }
                self.form = FormSession(
                    draft: FormDraft(form: form, prefill: prefill),
                    entry: target.entry,
                    action: action,
                    item: target.item,
                    openedSheet: opensSheet
                )
            } catch {
                closeMenu()
                host.notify("\(action.title) failed. \(Self.reason(error))")
            }
        }
    }

    public func changeSetting(_ key: String, of id: String) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }), let sheet = sheets[id] else { return false }
        let action = CommandAction(id: key, title: "Change \(key)", scope: .spot, after: .close)
        let ask = UUID()
        formAsk = ask
        Task {
            do {
                switch try await sheet.change(action) {
                case .form(let form)? where isShown && formAsk == ask:
                    pushFirst(id, moving: true)
                    self.form = FormSession(draft: FormDraft(form: form), entry: entry, action: action, item: nil, openedSheet: true)
                case .done?:
                    if isShown { host.dismiss() }
                default:
                    break
                }
            } catch {
                host.notify("\(action.title) failed. \(Self.reason(error))")
            }
        }
        return true
    }

    public func chooseFormOption(_ item: SpotItem) {
        form?.draft.choose(item.run)
        submitForm()
    }

    public func setFormValue(_ text: String, for name: String) {
        form?.draft.set(text, for: name)
    }

    public func cancelForm() {
        formAsk = nil
        guard let form else { return }
        self.form = nil
        if form.openedSheet {
            closeList(moving: true)
        }
    }

    public func submitForm() {
        guard let form else { return }
        if let missing = form.draft.missing {
            host.notify("Enter a value for \(missing.label).")
            return
        }
        send(form, form.draft)
    }

    private func send(_ form: FormSession, _ draft: FormDraft) {
        Task {
            do {
                switch try await sheets[form.entry.id]?.submit(form.action, item: form.item, draft: draft) {
                case .done? where self.form?.id == form.id:
                    self.form = nil
                    if form.action.after == .close, isShown { host.dismiss() }
                case .form(let next)? where self.form?.id == form.id:
                    let kept = FormDraft(form: next, after: self.form?.draft ?? draft)
                    self.form?.draft = kept
                default:
                    break
                }
            } catch {
                host.notify("\(form.action.title) failed. \(Self.reason(error))")
            }
        }
    }
}
