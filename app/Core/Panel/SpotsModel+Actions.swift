import Foundation
import Observation

/// The keys of the panel, the actions menu, the forms of actions and the recording of keys.
extension SpotsModel {
    /// What the actions menu and the action keys work on: the selected row, or else the selected card.
    private var target: Target? {
        if let entry = openEntry { return (entry, openSheet?.selectedItem) }
        guard let entry = selectedEntry else { return nil }
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.spot.id }) { return (list, item) }
        return (entry, nil)
    }

    /// Takes a key before the focused field does. Returns false when the key is not for an action, a menu or a form.
    public func handleKey(_ key: ActionKey) -> Bool {
        if menu != nil {
            return handleMenuKey(key)
        }
        if isEditing {
            if isSearchingDock, key.name != "escape" { return false }
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
        if key == Self.undoKey, openList == nil, searchText.isEmpty, undoRemoval() { return true }
        if let panel = openPanel, !panel.showsRows { return handlePanelKey(key, panel) }
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
        let quiet = searchText.isEmpty ? extras(on: target) : []
        guard let action = (target.entry.spot.actions(for: target.item) + quiet).first(where: { $0.key == key }) else { return openSheet(on: key) }
        if action.confirm != nil {
            openMenu(on: target)
            menu?.select(action)
            pressMenu()
        } else {
            run(action, on: target)
        }
        return true
    }

    /// Opens the sheet of the spot that the config gives this key of the panel, such as `⌘N`, when no action of the selected
    /// card takes the key and no sheet shows. Returns false for any other key.
    func openSheet(on key: ActionKey) -> Bool {
        guard openList == nil, let id = spot(openedBy: key) else { return false }
        endEditing(moving: false)
        open(id, moving: true)
        return true
    }

    /// The spot that the config gives a key of the panel, when it has a card.
    func spot(openedBy key: ActionKey) -> String? {
        arrangement.spot(openedBy: key, over: defaultArrangement).flatMap { id in entries.contains { $0.id == id } ? id : nil }
    }

    /// Does what the key of a footer label does, as if it were pressed: Return runs the selected row.
    public func pressHint(_ label: String) {
        guard let key = ActionKey(label: label) else { return }
        if !handleKey(key), key == ActionKey(name: "return") { runSelected() }
    }

    /// Takes the keys of the parts, Esc, the arrows and return, and leaves all others to the text areas. A part's own Esc wins
    /// over closing the sheet.
    private func handlePanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
        if let part = panel.parts.first(where: { $0.key == key }) {
            pressPart(part)
            return true
        }
        if key == ActionKey(name: "escape") {
            closeList(moving: true)
            return true
        }
        if panel.takesArrows, key == ActionKey(name: "up") || key == ActionKey(name: "down") {
            openSheet?.movePart(by: key.name == "up" ? -1 : 1)
            return true
        }
        if panel.scrollsByArrows, key == ActionKey(name: "up") || key == ActionKey(name: "down") {
            openSheet?.scrollPanel(by: key.name == "up" ? -1 : 1)
            return true
        }
        guard key == ActionKey(name: "return"), let part = panel.selectedPart else { return false }
        useSelected(part)
        return true
    }

    /// Does what a click on the control of this part does.
    private func useSelected(_ part: SpotPart) {
        switch part.control {
        case .shortcut: toggleRecording(part)
        case .toggle(let on): setPart(part, to: on ? "false" : "true")
        default: pressPart(part)
        }
    }

    public func setPart(_ part: SpotPart, to value: String) {
        openSheet?.set(part, to: value)
    }

    public func pressPart(_ part: SpotPart) {
        openSheet?.press(part)
        if part.closes, isShown { host.dismiss() }
    }

    /// Starts to record the next key for a part, with the entry key off so that it can be recorded too, or stops.
    public func toggleRecording(_ part: SpotPart) {
        toggleRecording(id: part.id)
    }

    /// Starts to record the next key for a part or a row, or stops.
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

    /// Takes the key for the part or the row that records. A key it cannot use leaves it recording, and says why. A row
    /// closes the panel, as a pick of any row does. In Edit Spots it takes the letter of the selected spot.
    public func record(code: UInt32, modifiers: Shortcut.Modifiers) {
        if isEditing { return recordLetter(code: code, modifiers: modifiers) }
        guard let shortcut = Shortcut(code: code, modifiers: modifiers) else {
            host.notify("Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.")
            return
        }
        let part = openPanel?.parts.first { $0.id == recording }
        let item = openItems?.shown.first { $0.run == recording }
        stopRecording()
        if let part { setPart(part, to: shortcut.text) }
        if let item, let entry = openEntry {
            sheets[entry.id]?.set(item, to: shortcut.text)
            closingPick = (item, entry)
            if isShown {
                host.dismiss()
            } else {
                finishPick()
            }
        }
    }

    /// Whether the row that records takes a shake too: a row that says `shake=true`, as a row of Settings that gives a key to
    /// a command or a float does (W3).
    public var takesShake: Bool {
        guard let recording else { return false }
        return openItems?.shown.first { $0.run == recording }?.takesShake ?? false
    }

    /// The words of the key that records.
    public var recordingWords: String {
        takesShake ? "Press keys or shake" : "Press keys"
    }

    /// Takes a shake for the row of Settings that records, as it takes a key, and closes the panel. Any other row goes on
    /// recording.
    public func recordShake() {
        guard takesShake, let recording, let entry = openEntry, let item = openItems?.shown.first(where: { $0.run == recording }) else { return }
        stopRecording()
        sheets[entry.id]?.set(item, to: Trigger.shake.text)
        closingPick = (item, entry)
        if isShown {
            host.dismiss()
        } else {
            finishPick()
        }
    }

    /// Takes the keys of the open menu. In a menu that searches, a key with no ⌘ goes to its field, and returns false.
    private func handleMenuKey(_ key: ActionKey) -> Bool {
        let types = menu?.isSearchable == true && !key.isCommand
        switch key {
        case ActionKey(name: "k", isCommand: true), ActionKey(name: "escape"): closeMenu()
        case ActionKey(name: "up"): menu?.move(by: -1)
        case ActionKey(name: "down"): menu?.move(by: 1)
        case ActionKey(name: "return"): pressMenu()
        default:
            guard !types, let action = menu?.rows.compactMap(\.action).first(where: { $0.key == key }) else { return !types }
            menu?.select(action)
            pressMenu()
        }
        return true
    }

    /// Selects the row of the open menu that the pointer moved onto.
    public func pointMenu(row: Int) {
        guard let menu else { return }
        self.menu?.move(by: row - menu.selected)
    }

    /// Highlights the row of the open menu under a point of the panel, as a force click is dragged.
    public func dragMenu(to point: CGPoint) {
        if let row = menuRow(at: point) { pointMenu(row: row) }
    }

    /// Runs the row of the open menu under a point of the panel, where a dragged force click ends. Off the rows the menu stays.
    public func releaseMenu(at point: CGPoint) {
        if let row = menuRow(at: point) { pressMenu(row: row) }
    }

    private func menuRow(at point: CGPoint) -> Int? {
        guard let menu, let menuPlace else { return nil }
        let rect = menuPlace.rect(height: SpotTokens.menuHeight(rows: menu.lines))
        return menu.row(at: point, in: rect, fieldIsLast: menuPlace.growsUp)
    }

    public func searchMenu(_ text: String) {
        menu?.search(text)
    }

    /// Selects the card at this point of the grid and opens its actions menu, as `⌘K` does, for a right or force click. A
    /// sheet or Edit Spots takes none.
    public func openMenu(at point: CGPoint) {
        guard openList == nil, !isEditing, let id = card(at: point), let index = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = index
        if let target { openMenu(on: target) }
    }

    private func openMenu(on target: Target) {
        menu = actionMenu(on: target)
        menuTarget = target
        closingMenu = nil
        menuIsGrown = false
        menuIsSettled = false
        DispatchQueue.main.async { [weak self] in
            guard let self, menu != nil else { return }
            change(.sheet(isOpen: true), { self.menuIsGrown = true }, completion: { [weak self] in
                if self?.menuIsGrown == true { self?.menuIsSettled = true }
            })
        }
    }

    private func actionMenu(on target: Target) -> ActionMenu? {
        let isOpenList = openList == target.entry.id
        return ActionMenu(
            spot: target.entry.spot,
            item: target.item,
            showsPrimary: !isOpenList || target.item != nil,
            extras: extras(on: target)
        )
    }

    /// The rows that the app adds for a selected card of the grid: the acts on the file of a spot of the person, and on a
    /// card of a file that does not load. A core spot can be shared and turned off. A row of a list or an open sheet keeps its
    /// own Delete.
    private func extras(on target: Target) -> [CommandAction] {
        guard openList == nil, target.item == nil else { return [] }
        let command = target.entry.spot
        if command.fault != nil { return [.edit, .remove()] }
        guard command.host == nil, !command.isBuiltIn else { return [] }
        guard !files.folder(Config(text: "")).isCore(command) else { return [.share, .turnOff] }
        return [.edit, .copyPrompt, .share, .remove(widgets: widgets(sharingFileWith: target.entry))]
    }

    /// How many widgets the file of a widget holds, which go together when it is removed.
    private func widgets(sharingFileWith entry: Entry) -> Int {
        entry.kind == .widget ? entries.filter { $0.spot.url == entry.spot.url }.count : 1
    }

    /// The keys that work on the selected row or card, in words for the bottom of the panel.
    public var hint: String {
        if recording != nil, isEditing { return "Press a letter   ⌫ Remove   Esc Cancel" }
        if recording != nil { return "Esc Cancel" }
        if isEditing { return "S Size   H Hide   L Letter   ⇧ Arrows Move   Esc Done" }
        if spotDrop != nil { return "Nothing runs until you press ⌘⏎" }
        if let panel = openPanel, !panel.showsRows || panel.drawsKeys { return panel.hint { work(of: $0) != nil } }
        let keys = target.flatMap { target in
            actionMenu(on: target)?.hint { sheets[target.entry.id]?.work(of: $0, item: target.item) != nil }
        } ?? "Esc Close"
        return selectedGlyphTitle.map { "\($0)  \(keys)" } ?? keys
    }

    /// The name of the selected spot when it shows only a glyph.
    private var selectedGlyphTitle: String? {
        guard openList == nil, let entry = selectedEntry, entry.kind != .widget,
              placements.first(where: { $0.index == selected })?.size == .small
        else { return nil }
        return entry.state.title
    }

    /// Closes the menu at once for keys and the focus, and leaves its look to fade back into its item, then lets it go.
    public func closeMenu() {
        guard let open = menu else { return }
        closingMenu = open
        menu = nil
        menuTarget = nil
        menuIsSettled = false
        change(.sheet(isOpen: false), { menuIsGrown = false }, completion: { [weak self] in
            guard let self, menu == nil else { return }
            closingMenu = nil
            menuPlace = nil
        })
    }

    public func pressMenu(row: Int) {
        guard let menu else { return }
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
        if let action = row.action {
            run(action, on: target)
        } else if let item = target.item {
            pick(item, of: target.entry)
        } else {
            run(target.entry)
        }
    }

    /// Runs an action on a row or on the whole spot. In a float, an action that asks with a form or for a second press opens
    /// the spot in the panel, where both work, and any other runs at once and leaves the float open (W8).
    public func run(_ action: CommandAction, on target: Target, in place: SheetPlace = .panel) {
        if place == .float {
            if action.isForm || action.confirm != nil {
                press(target.entry.id)
            } else {
                sheets[target.entry.id]?.run(action, item: target.item)
            }
        } else if action == .share {
            share(target.entry)
        } else if action.id == CommandAction.removeID {
            remove(target.entry)
        } else if action == .edit {
            if isShown { host.dismiss() }
            edit(target.entry)
        } else if action == .copyPrompt {
            copyPrompt(changing: target.entry)
        } else if action == .turnOff {
            turnOff(target.entry)
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

    /// Asks the script for the form of an action, and shows it in place of the actions menu once it comes, so that the menu
    /// stays while the script answers.
    public func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        let ask = UUID()
        formAsk = ask
        Task {
            do {
                guard let form = try await sheets[target.entry.id]?.form(action, item: target.item), formAsk == ask else { return }
                formAsk = nil
                closeMenu()
                let opensSheet = openList != target.entry.id
                if opensSheet {
                    open(target.entry.id, moving: isShown)
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

    /// Runs the action of a spot that has the name of its setting, as `openspot setting change` asks. A form that it answers
    /// with opens on the sheet of that spot, and the panel closes when it is done. Returns false when no spot has the ID.
    public func changeSetting(_ key: String, of id: String) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }), let sheet = sheets[id] else { return false }
        let action = CommandAction(id: key, title: "Change \(key)", scope: .command, after: .close)
        let ask = UUID()
        formAsk = ask
        Task {
            do {
                switch try await sheet.change(action) {
                case .form(let form)? where isShown && formAsk == ask:
                    open(id, moving: true)
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

    /// Takes a click on an option of a form of one choice, and saves the form with it.
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

    /// Saves the form. It stays open with its text when the command refuses the values, and shows the form that the command
    /// answers with. An action that closes the panel closes it once the command is done. A call that ends after the person
    /// moved on to another form changes nothing.
    public func submitForm() {
        guard let form else { return }
        if let missing = form.draft.missing {
            host.notify("Enter a value for \(missing.label).")
            return
        }
        send(form, form.draft)
    }

    /// Gives a draft of the form to its command. A form that it answers with keeps the selected row.
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
